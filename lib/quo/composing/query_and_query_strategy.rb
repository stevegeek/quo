# frozen_string_literal: true

require_relative "instance_strategy"

module Quo
  module Composing
    # Strategy for composing two Query instances
    class QueryAndQueryStrategy < InstanceStrategy
      def applicable?(left, right)
        left.is_a?(Quo::Query) && right.is_a?(Quo::Query)
      end

      def compose(left, right, joins: nil)
        validate_instances(left, right)

        props = merged_properties(left, right)
        joins_array = normalize_joins(joins)
        specs = extract_specifications(left, right)
        base_class = determine_base_class_for_queries(left, right)

        # Create the composed class and instantiate it
        create_composed_instance(
          base_class,
          left.class,
          right.class,
          joins: joins_array,
          left_spec: specs[:left],
          right_spec: specs[:right],
          props: props
        )
      end

      private

      # Merge properties from both queries, excluding specifications
      def merged_properties(left, right)
        left_props = left.to_h
        right_props = right.to_h.compact

        # Remove specifications as they apply to specific queries only
        left_props.delete(:_specification)
        right_props.delete(:_specification)

        left_props.merge(right_props)
      end

      # Normalize joins to always be an array
      def normalize_joins(joins)
        joins ||= []
        joins.is_a?(Array) ? joins : [joins]
      end

      # Extract specifications from both queries if they are relation-backed
      def extract_specifications(left, right)
        {
          left: left.is_a?(Quo::RelationBackedQuery) ? left._specification : nil,
          right: right.is_a?(Quo::RelationBackedQuery) ? right._specification : nil
        }
      end

      # Create the composed instance with the appropriate parameters
      def create_composed_instance(base_class, left_class, right_class, joins:, left_spec:, right_spec:, props:)
        Quo::Composing.composer(
          base_class,
          left_class,
          right_class,
          joins: joins,
          left_spec: left_spec,
          right_spec: right_spec
        ).new(**props)
      end
    end
  end
end
