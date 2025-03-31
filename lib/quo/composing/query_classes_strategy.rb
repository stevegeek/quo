# frozen_string_literal: true

# rbs_inline: enabled

require_relative "class_strategy"

module Quo
  module Composing
    # Strategy for composing two Query classes
    class QueryClassesStrategy < ClassStrategy
      # @rbs override
      # @rbs left: Class
      # @rbs right: Class
      # @rbs return: bool
      def applicable?(left, right)
        left.respond_to?(:<) && right.respond_to?(:<) &&
          (left < Quo::Query || left.is_a?(::ActiveRecord::Relation)) &&
          (right < Quo::Query || right.is_a?(::ActiveRecord::Relation))
      end

      # @rbs override
      # @rbs chosen_superclass: Class
      # @rbs left_query_class: Class
      # @rbs right_query_class: Class
      # @rbs joins: Symbol | Hash[Symbol, untyped] | Array[Symbol | Hash[Symbol, untyped]]?
      # @rbs left_spec: Quo::RelationBackedQuerySpecification?
      # @rbs right_spec: Quo::RelationBackedQuerySpecification?
      # @rbs return: Class & Quo::ComposedQuery
      def compose(chosen_superclass, left_query_class, right_query_class, joins: nil, left_spec: nil, right_spec: nil)
        validate_query_classes(left_query_class, right_query_class)
        props = collect_properties(left_query_class, right_query_class)
        klass = create_composed_class(chosen_superclass, props)
        assign_query_metadata(klass, left_query_class, right_query_class, joins, left_spec, right_spec)
        klass
      end
    end
  end
end
