# frozen_string_literal: true

module Quo
  class ComposedQuery < Quo::Query
    class << self
      # Combine two Query classes into a new composed query class
      def compose(left_query_class, right_query_class, joins: nil)
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
      def merge_instances(left_instance, right_instance, joins: nil)
        raise ArgumentError, "Cannot merge, left has incompatible type #{left_instance.class}" unless left_instance.is_a?(Quo::Query) || left_instance.is_a?(::ActiveRecord::Relation)
        raise ArgumentError, "Cannot merge, right has incompatible type #{right_instance.class}" unless right_instance.is_a?(Quo::Query) || right_instance.is_a?(::ActiveRecord::Relation)
        return compose(left_instance.class, right_instance, joins: joins).new(**left_instance.to_h) if left_instance.is_a?(Quo::Query) && right_instance.is_a?(::ActiveRecord::Relation)
        return compose(left_instance, right_instance.class, joins: joins).new(**right_instance.to_h) if right_instance.is_a?(Quo::Query) && left_instance.is_a?(::ActiveRecord::Relation)
        return compose(left_instance.class, right_instance.class, joins: joins).new(**left_instance.to_h.merge(right_instance.to_h)) if left_instance.is_a?(Quo::Query) && right_instance.is_a?(Quo::Query)
        compose(left_instance, right_instance, joins: joins).new # Both are relations
      end

      def inspect
        "Quo::ComposedQuery[#{operand_desc(_left_query)}, #{operand_desc(_right_query)}]"
      end

      private

      def operand_desc(operand)
        if operand < Quo::ComposedQuery
          operand.inspect
        else
          operand.name || "(anonymous)"
        end
      end
    end

    def query
      merge_left_and_right(left, right, _composing_joins)
    end

    def left
      return _left_query if relation?(_left_query)
      _left_query.new(**child_options(_left_query))
    end

    def right
      return _right_query if relation?(_right_query)
      _right_query.new(**child_options(_right_query))
    end

    delegate :_composing_joins, :_left_query, :_right_query, to: :class

    def inspect
      "Quo::ComposedQuery[#{operand_desc(left)}, #{operand_desc(right)}]"
    end

    private

    def child_options(query_class)
      names = property_names(query_class)
      to_h.slice(*names)
    end

    def property_names(query_class)
      query_class.literal_properties.properties_index.keys
    end

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

    def apply_joins(left_rel, joins)
      joins.present? ? left_rel.joins(joins) : left_rel
    end

    def relation?(rel)
      rel.is_a?(::ActiveRecord::Relation)
    end

    def both_relations?(left, right)
      relation?(left) && relation?(right)
    end

    def left_relation_right_enumerable?(left, right)
      relation?(left) && !relation?(right)
    end

    def left_enumerable_right_relation?(left, right)
      !relation?(left) && relation?(right)
    end

    def unwrap_relation(query)
      query.is_a?(Quo::Query) ? query.unwrap_unpaginated : query
    end

    def operand_desc(operand)
      if operand.is_a? Quo::ComposedQuery
        operand.inspect
      else
        operand.class.name || operand.class.superclass
      end
    end
  end
end
