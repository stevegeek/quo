# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  # @rbs inherits Quo::Query
  class ComposedQuery < Quo.base_query_class
    # Combine two Query classes into a new composed query class
    # Combine two query-like or composeable entities:
    # These can be Quo::Query, Quo::ComposedQuery, Quo::CollectionBackedQuery and ActiveRecord::Relations.
    # See the `README.md` docs for more details.
    # @rbs left_query_class: singleton(Quo::Query | ::ActiveRecord::Relation)
    # @rbs right_query_class: singleton(Quo::Query | ::ActiveRecord::Relation)
    # @rbs joins: untyped
    # @rbs return: singleton(Quo::ComposedQuery)
    def self.composer(left_query_class, right_query_class, joins: nil)
      raise ArgumentError, "Cannot compose #{left_query_class}" unless left_query_class.respond_to?(:<)
      props = {}
      props.merge!(left_query_class.literal_properties.properties_index) if left_query_class < Quo::Query
      props.merge!(right_query_class.literal_properties.properties_index) if right_query_class < Quo::Query

      klass = Class.new(self) do
        class << self
          attr_reader :_composing_joins, :_left_query, :_right_query
        end

        props.each do |name, property|
          prop name, property.type, property.kind, reader: property.reader, writer: property.writer, default: property.default, shadow_check: false
        end
      end
      klass.instance_variable_set(:@_composing_joins, joins)
      klass.instance_variable_set(:@_left_query, left_query_class)
      klass.instance_variable_set(:@_right_query, right_query_class)
      # klass.set_temporary_name = "quo::ComposedQuery" # Ruby 3.3+
      klass
    end

    # We can also merge instance of prepared queries
    # @rbs left_instance: Quo::Query | ::ActiveRecord::Relation
    # @rbs right_instance: Quo::Query | ::ActiveRecord::Relation
    # @rbs joins: untyped
    # @rbs return: Quo::ComposedQuery
    def self.merge_instances(left_instance, right_instance, joins: nil)
      raise ArgumentError, "Cannot merge, left has incompatible type #{left_instance.class}" unless left_instance.is_a?(Quo::Query) || left_instance.is_a?(::ActiveRecord::Relation)
      raise ArgumentError, "Cannot merge, right has incompatible type #{right_instance.class}" unless right_instance.is_a?(Quo::Query) || right_instance.is_a?(::ActiveRecord::Relation)
      if left_instance.is_a?(Quo::Query) && right_instance.is_a?(::ActiveRecord::Relation)
        return composer(left_instance.class, right_instance, joins: joins).new(**left_instance.to_h)
      elsif right_instance.is_a?(Quo::Query) && left_instance.is_a?(::ActiveRecord::Relation)
        return composer(left_instance, right_instance.class, joins: joins).new(**right_instance.to_h)
      elsif left_instance.is_a?(Quo::Query) && right_instance.is_a?(Quo::Query)
        props = left_instance.to_h.merge(right_instance.to_h.compact)
        return composer(left_instance.class, right_instance.class, joins: joins).new(**props)
      end
      composer(left_instance, right_instance, joins: joins).new # Both are relations
    end

    # @rbs override
    def self.inspect
      left = _left_query
      left_desc = (left < Quo::ComposedQuery) ? left.inspect : (left.name || "(anonymous)")
      right = _right_query
      right_desc = (right < Quo::ComposedQuery) ? right.inspect : (right.name || "(anonymous)")
      "Quo::ComposedQuery[#{left_desc}, #{right_desc}]"
    end

    # @rbs override
    def query
      merge_left_and_right(left, right, _composing_joins)
    end

    # @rbs return: Quo::Query | ::ActiveRecord::Relation
    def left
      return _left_query if is_relation?(_left_query)
      _left_query.new(**child_options(_left_query))
    end

    # @rbs return: Quo::Query | ::ActiveRecord::Relation
    def right
      return _right_query if is_relation?(_right_query)
      _right_query.new(**child_options(_right_query))
    end

    delegate :_composing_joins, :_left_query, :_right_query, to: :class

    # @rbs override
    def inspect
      "Quo::ComposedQuery[#{operand_desc(left)}, #{operand_desc(right)}]"
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

    # @rbs return: ActiveRecord::Relation | Object & Enumerable[untyped]
    def merge_left_and_right(left, right, joins)
      left_rel = unwrap_relation(left)
      right_rel = unwrap_relation(right)
      # FIXME: Skipping type checks here, as not sure how to make this type check with RBS
      __skip__ = if both_relations?(left_rel, right_rel)
        apply_joins(left_rel, joins).merge(right_rel)
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
    # @rbs joins: untyped
    # @rbs return: ActiveRecord::Relation
    def apply_joins(left_rel, joins)
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

    # @rbs override
    def unwrap_relation(query)
      query.is_a?(Quo::Query) ? query.unwrap_unpaginated : query
    end

    # @rbs operand: Quo::ComposedQuery | Quo::Query | ::ActiveRecord::Relation
    # @rbs return: String
    def operand_desc(operand)
      if operand.is_a? Quo::ComposedQuery
        operand.inspect
      else
        operand.class.name || operand.class.superclass&.name || "(anonymous)"
      end
    end
  end
end
