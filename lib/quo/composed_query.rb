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
    def composer(chosen_superclass, left_query_class, right_query_class, joins: nil, left_spec: nil, right_spec: nil)
      validate_query_classes(left_query_class, right_query_class)

      props = collect_properties(left_query_class, right_query_class)
      klass = create_composed_class(chosen_superclass, props)

      assign_query_metadata(klass, left_query_class, right_query_class, joins, left_spec, right_spec)
      klass
    end
    module_function :composer

    # We can also merge instance of prepared queries
    # @rbs left_instance: Quo::Query | ::ActiveRecord::Relation
    # @rbs right_instance: Quo::Query | ::ActiveRecord::Relation
    # @rbs joins: untyped
    # @rbs return: Quo::ComposedQuery
    def merge_instances(left_instance, right_instance, joins: nil)
      validate_instances(left_instance, right_instance)

      if left_instance.is_a?(Quo::Query) && right_instance.is_a?(::ActiveRecord::Relation)
        return merge_query_and_relation(left_instance, right_instance, joins)
      elsif right_instance.is_a?(Quo::Query) && left_instance.is_a?(::ActiveRecord::Relation)
        return merge_relation_and_query(left_instance, right_instance, joins)
      elsif left_instance.is_a?(Quo::Query) && right_instance.is_a?(Quo::Query)
        return merge_query_instances(left_instance, right_instance, joins)
      end

      # Both are AR relations
      composer(Quo.relation_backed_query_base_class, left_instance, right_instance, joins: joins).new
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

    class << self
      private

      # @rbs left_query_class: singleton(Quo::Query | ::ActiveRecord::Relation)
      # @rbs right_query_class: singleton(Quo::Query | ::ActiveRecord::Relation)
      def validate_query_classes(left_query_class, right_query_class)
        unless left_query_class.respond_to?(:<) && right_query_class.respond_to?(:<)
          raise ArgumentError, "Cannot compose #{left_query_class} and #{right_query_class}, are they both classes? If you want to use instances use `.merge_instances`"
        end
      end

      # @rbs left_query_class: singleton(Quo::Query | ::ActiveRecord::Relation)
      # @rbs right_query_class: singleton(Quo::Query | ::ActiveRecord::Relation)
      def collect_properties(left_query_class, right_query_class)
        props = {}
        props.merge!(left_query_class.literal_properties.properties_index) if left_query_class < Quo::Query
        props.merge!(right_query_class.literal_properties.properties_index) if right_query_class < Quo::Query
        props
      end

      def create_composed_class(chosen_superclass, props)
        Class.new(chosen_superclass) do
          include Quo::ComposedQuery

          class << self
            attr_reader :_composing_joins, :_left_specification, :_right_specification, :_left_query, :_right_query

            def inspect
              left_desc = quo_operand_desc(_left_query)
              right_desc = quo_operand_desc(_right_query)
              klass_name = determine_class_name
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

            private

            # @rbs return: String
            def determine_class_name
              if self < Quo::RelationBackedQuery
                Quo.relation_backed_query_base_class.name
              else
                Quo.collection_backed_query_base_class.name
              end
            end
          end

          props.each do |name, property|
            prop(
              name,
              property.type,
              property.kind,
              reader: property.reader,
              writer: property.writer,
              default: property.default
            )
          end
        end
      end

      # @rbs klass: Class
      # @rbs left_query_class: singleton(Quo::Query | ::ActiveRecord::Relation)
      # @rbs right_query_class: singleton(Quo::Query | ::ActiveRecord::Relation)
      # @rbs joins: untyped
      def assign_query_metadata(klass, left_query_class, right_query_class, joins, left_spec, right_spec)
        # merge spec and joins
        left_joins = left_spec ? left_spec[:joins] : []
        left_joins = left_joins.is_a?(Array) ? left_joins : [left_joins]
        joins = joins.is_a?(Array) ? joins : [joins] if joins
        merge_left_joins = joins ? joins + left_joins : left_joins

        klass.instance_variable_set(:@_composing_joins, merge_left_joins)
        klass.instance_variable_set(:@_left_specification, left_spec)
        klass.instance_variable_set(:@_right_specification, right_spec)
        klass.instance_variable_set(:@_left_query, left_query_class)
        klass.instance_variable_set(:@_right_query, right_query_class)
      end

      # @rbs left_instance: Quo::Query | ::ActiveRecord::Relation
      # @rbs right_instance: Quo::Query | ::ActiveRecord::Relation
      def validate_instances(left_instance, right_instance)
        unless left_instance.is_a?(Quo::Query) || left_instance.is_a?(::ActiveRecord::Relation)
          raise ArgumentError, "Cannot merge, left has incompatible type #{left_instance.class}"
        end

        unless right_instance.is_a?(Quo::Query) || right_instance.is_a?(::ActiveRecord::Relation)
          raise ArgumentError, "Cannot merge, right has incompatible type #{right_instance.class}"
        end
      end

      # @rbs relation: ::ActiveRecord::Relation
      # @rbs query: Quo::Query
      # @rbs joins: untyped
      def merge_query_and_relation(query, relation, joins)
        base_class = query.is_a?(Quo::RelationBackedQuery) ?
                    Quo.relation_backed_query_base_class :
                    Quo.collection_backed_query_base_class

        composer(base_class, query.class, relation, joins: joins).new(**query.to_h)
      end

      # @rbs relation: ::ActiveRecord::Relation
      # @rbs query: Quo::Query
      # @rbs joins: untyped
      def merge_relation_and_query(relation, query, joins)
        base_class = query.is_a?(Quo::RelationBackedQuery) ?
                    Quo.relation_backed_query_base_class :
                    Quo.collection_backed_query_base_class

        composer(base_class, relation, query.class, joins: joins).new(**query.to_h)
      end

      # @rbs left_query: Quo::Query | ::ActiveRecord::Relation
      # @rbs right_query: Quo::Query | ::ActiveRecord::Relation
      # @rbs joins: untyped
      def merge_query_instances(left_query, right_query, joins)
        left_props = left_query.to_h
        # Do not merge query specifications as those apply to the specific query they are for.
        left_props.delete(:_specification)
        right_props = right_query.to_h.compact
        right_props.delete(:_specification)
        props = left_props.merge(right_props)

        joins ||= []
        joins = joins.is_a?(Array) ? joins : [joins]
        left_spec = left_query._specification if left_query.is_a?(Quo::RelationBackedQuery)
        right_spec = right_query._specification if right_query.is_a?(Quo::RelationBackedQuery)

        base_class = determine_base_class_for_queries(left_query, right_query)
        composer(base_class, left_query.class, right_query.class, joins: joins, left_spec: left_spec, right_spec: right_spec).new(**props)
      end

      # @rbs left_query: Quo::Query | ::ActiveRecord::Relation
      # @rbs right_query: Quo::Query | ::ActiveRecord::Relation
      def determine_base_class_for_queries(left_query, right_query)
        both_relation_backed = left_query.is_a?(Quo::RelationBackedQuery) &&
          right_query.is_a?(Quo::RelationBackedQuery)

        both_relation_backed ? Quo.relation_backed_query_base_class :
                              Quo.collection_backed_query_base_class
      end
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
      instance = lq.new(**child_options(lq))
      if lq < Quo::RelationBackedQuery
        instance.with_specification(self.class._left_specification)
      else
        instance
      end
    end

    # @rbs return: Quo::Query | ::ActiveRecord::Relation
    def right
      rq = self.class._right_query
      return rq if is_relation?(rq)
      # rq.new(**child_options(rq)).with_specification(self.class._right_specification)
      instance = rq.new(**child_options(rq))
      if rq < Quo::RelationBackedQuery
        instance.with_specification(self.class._right_specification)
      else
        instance
      end
    end

    # @rbs return: ActiveRecord::Relation | CollectionBackedQuery
    def merge_left_and_right
      left_rel = quo_unwrap_unpaginated_query(left)
      right_rel = quo_unwrap_unpaginated_query(right)

      if both_relations?(left_rel, right_rel)
        merge_active_record_relations(left_rel, right_rel)
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
    # @rbs right_rel: ActiveRecord::Relation
    # @rbs return: ActiveRecord::Relation
    def merge_active_record_relations(left_rel, right_rel)
      joins = self.class._composing_joins
      left_rel = left_rel.joins(joins) if joins
      left_rel.merge(right_rel)
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
