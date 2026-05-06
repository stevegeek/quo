# frozen_string_literal: true

# rbs_inline: enabled

require_relative "base_strategy"

module Quo
  module Composing
    # Base class for class composition strategies
    class ClassStrategy < BaseStrategy
      # @rbs left_query_class: Class
      # @rbs right_query_class: Class
      # @rbs return: void
      def validate_query_classes(left_query_class, right_query_class)
        unless left_query_class.respond_to?(:<) && right_query_class.respond_to?(:<)
          raise ArgumentError, "Cannot compose #{left_query_class} and #{right_query_class}, are they both classes? If you want to use instances use `.merge_instances`"
        end
      end

      # Collect properties that need to be (re)defined on the composed class.
      # Properties already declared on `chosen_superclass` are inherited via the
      # normal Ruby/Literal class hierarchy and do not need to be re-registered;
      # skipping them avoids the per-prop Literal::Property allocation, schema
      # dup, and `module_eval` of reader/writer source on every Class.new.
      # @rbs chosen_superclass: Class
      # @rbs left_query_class: Class
      # @rbs right_query_class: Class
      # @rbs return: Hash[Symbol, Literal::Property]
      def collect_properties(chosen_superclass, left_query_class, right_query_class)
        existing = chosen_superclass.literal_properties.properties_index
        props = {}
        if left_query_class < Quo::Query
          left_query_class.literal_properties.properties_index.each do |name, property|
            props[name] = property unless existing.key?(name)
          end
        end
        if right_query_class < Quo::Query
          right_query_class.literal_properties.properties_index.each do |name, property|
            props[name] = property unless existing.key?(name)
          end
        end
        props
      end

      # @rbs chosen_superclass: Class
      # @rbs props: Hash[Symbol, Literal::Property]
      # @rbs return: Class & Quo::ComposedQuery
      def create_composed_class(chosen_superclass, props)
        Class.new(chosen_superclass) do
          include Quo::ComposedQuery
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
      # @rbs left_query_class: Class
      # @rbs right_query_class: Class
      # @rbs joins: Symbol | Hash[Symbol, untyped] | Array[Symbol | Hash[Symbol, untyped]]?
      # @rbs left_spec: Quo::RelationBackedQuerySpecification?
      # @rbs right_spec: Quo::RelationBackedQuerySpecification?
      # @rbs return: void
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
    end
  end
end
