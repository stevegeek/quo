# frozen_string_literal: true

require_relative "class_strategy"

module Quo
  module Composing
    # Strategy for composing two Query classes
    class QueryClassesStrategy < ClassStrategy
      def applicable?(left, right)
        left.respond_to?(:<) && right.respond_to?(:<) &&
          (left < Quo::Query || left.is_a?(::ActiveRecord::Relation)) &&
          (right < Quo::Query || right.is_a?(::ActiveRecord::Relation))
      end

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
