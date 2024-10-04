# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  module ComposedQuery
    # Combine two Query classes into a new composed query class
    # Combine two query-like or composeable entities:
    # These can be Quo::Query, Quo::ComposedQuery, Quo::CollectionBackedQuery and ActiveRecord::Relations.
    # See the `README.md` docs for more details.
    # @rbs chosen_superclass: singleton(Quo::RelationBackedQuery | Quo::CollectionBackedQuery)
    # @rbs left_query_class: singleton(Quo::Query | ::ActiveRecord::Relation)
    # @rbs right_query_class: singleton(Quo::Query | ::ActiveRecord::Relation)
    # @rbs joins: untyped
    # @rbs return: singleton(Quo::ComposedQuery)
    def composer(chosen_superclass, left_query_class, right_query_class, joins: nil)
      unless left_query_class.respond_to?(:<) && right_query_class.respond_to?(:<)
        raise ArgumentError, "Cannot compose #{left_query_class} and #{right_query_class}, are they both classes? If you want to use instances use `.merge_instances`"
      end
      props = {}
      props.merge!(left_query_class.literal_properties.properties_index) if left_query_class < Quo::Query
      props.merge!(right_query_class.literal_properties.properties_index) if right_query_class < Quo::Query

      klass = Class.new(chosen_superclass) do
        include Quo::ComposedQuery

        class << self
          attr_reader :_composing_joins, :_left_query, :_right_query

          def inspect
            left_desc = quo_operand_desc(_left_query)
            right_desc = quo_operand_desc(_right_query)
            klass_name = (self < Quo::RelationBackedQuery) ? Quo::RelationBackedQuery.name : Quo::CollectionBackedQuery.name
            "#{klass_name}<Quo::ComposedQuery>[#{left_desc}, #{right_desc}]"
          end

          # @rbs operand: Quo::ComposedQuery | Quo::Query | ::ActiveRecord::Relation
          # @rbs return: String
          def quo_operand_desc(operand)
            if operand < Quo::ComposedQuery
              operand.inspect
            else
              operand.name || operand.superclass&.name || "(anonymous)"
            end
          end
        end

        props.each do |name, property|
          prop name, property.type, property.kind, reader: property.reader, writer: property.writer, default: property.default
        end
      end
      klass.instance_variable_set(:@_composing_joins, joins)
      klass.instance_variable_set(:@_left_query, left_query_class)
      klass.instance_variable_set(:@_right_query, right_query_class)
      klass
    end
    module_function :composer

    # We can also merge instance of prepared queries
    # @rbs left_instance: Quo::Query | ::ActiveRecord::Relation
    # @rbs right_instance: Quo::Query | ::ActiveRecord::Relation
    # @rbs joins: untyped
    # @rbs return: Quo::ComposedQuery
    def merge_instances(left_instance, right_instance, joins: nil)
      raise ArgumentError, "Cannot merge, left has incompatible type #{left_instance.class}" unless left_instance.is_a?(Quo::Query) || left_instance.is_a?(::ActiveRecord::Relation)
      raise ArgumentError, "Cannot merge, right has incompatible type #{right_instance.class}" unless right_instance.is_a?(Quo::Query) || right_instance.is_a?(::ActiveRecord::Relation)
      if left_instance.is_a?(Quo::Query) && right_instance.is_a?(::ActiveRecord::Relation)
        return composer(left_instance.is_a?(Quo::RelationBackedQuery) ? Quo::RelationBackedQuery : Quo::CollectionBackedQuery, left_instance.class, right_instance, joins: joins).new(**left_instance.to_h)
      elsif right_instance.is_a?(Quo::Query) && left_instance.is_a?(::ActiveRecord::Relation)
        return composer(right_instance.is_a?(Quo::RelationBackedQuery) ? Quo::RelationBackedQuery : Quo::CollectionBackedQuery, left_instance, right_instance.class, joins: joins).new(**right_instance.to_h)
      elsif left_instance.is_a?(Quo::Query) && right_instance.is_a?(Quo::Query)
        props = left_instance.to_h.merge(right_instance.to_h.compact)
        return composer((left_instance.is_a?(Quo::RelationBackedQuery) && right_instance.is_a?(Quo::RelationBackedQuery)) ? Quo::RelationBackedQuery : Quo::CollectionBackedQuery, left_instance.class, right_instance.class, joins: joins).new(**props)
      end
      composer(Quo::RelationBackedQuery, left_instance, right_instance, joins: joins).new # Both are AR relations
    end
    module_function :merge_instances

    # @rbs override
    def query
      merge_left_and_right
    end

    # @rbs override
    def inspect
      klass_name = is_a?(Quo::RelationBackedQuery) ? Quo::RelationBackedQuery.name : Quo::CollectionBackedQuery.name
      "#{klass_name}<Quo::ComposedQuery>[#{self.class.quo_operand_desc(left.class)}, #{self.class.quo_operand_desc(right.class)}](#{super})"
    end

    private

    # @rbs return: Hash[Symbol, untyped]
    def child_options(query_class)
      names = property_names(query_class)
      to_h.slice(*names)
    end

    # @rbs return: Array[Symbol]
    def property_names(query_class)
      query_class.literal_properties.properties_index.keys
    end

    # @rbs return: Quo::Query | ::ActiveRecord::Relation
    def left
      lq = self.class._left_query
      return lq if is_relation?(lq)
      lq.new(**child_options(lq))
    end

    # @rbs return: Quo::Query | ::ActiveRecord::Relation
    def right
      rq = self.class._right_query
      return rq if is_relation?(rq)
      rq.new(**child_options(rq))
    end

    # @rbs return: ActiveRecord::Relation | CollectionBackedQuery
    def merge_left_and_right
      left_rel = quo_unwrap_unpaginated_query(left)
      right_rel = quo_unwrap_unpaginated_query(right)
      if both_relations?(left_rel, right_rel)
        apply_joins(left_rel).merge(right_rel) # ActiveRecord::Relation
      elsif left_relation_right_enumerable?(left_rel, right_rel)
        left_rel.to_a + right_rel
      elsif left_enumerable_right_relation?(left_rel, right_rel) && left_rel.respond_to?(:+)
        left_rel + right_rel.to_a
      elsif left_rel.respond_to?(:+)
        left_rel + right_rel
      else
        raise ArgumentError, "Cannot merge #{left.class} with #{right.class}"
      end
    end

    # @rbs left_rel: ActiveRecord::Relation
    # @rbs return: ActiveRecord::Relation
    def apply_joins(left_rel)
      joins = self.class._composing_joins
      joins.present? ? left_rel.joins(joins) : left_rel
    end

    # @rbs rel: untyped
    # @rbs return: bool
    def is_relation?(rel)
      rel.is_a?(::ActiveRecord::Relation)
    end

    # @rbs left: untyped
    # @rbs right: untyped
    # @rbs return: bool
    def both_relations?(left, right)
      is_relation?(left) && is_relation?(right)
    end

    # @rbs left: untyped
    # @rbs right: untyped
    # @rbs return: bool
    def left_relation_right_enumerable?(left, right)
      is_relation?(left) && !is_relation?(right)
    end

    # @rbs left: untyped
    # @rbs right: untyped
    # @rbs return: bool
    def left_enumerable_right_relation?(left, right)
      !is_relation?(left) && is_relation?(right)
    end
  end
end
