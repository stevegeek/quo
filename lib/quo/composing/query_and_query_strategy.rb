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

        left_props = left.to_h
        # Do not merge query specifications as those apply to the specific query they are for.
        left_props.delete(:_specification)
        right_props = right.to_h.compact
        right_props.delete(:_specification)
        props = left_props.merge(right_props)

        joins ||= []
        joins = joins.is_a?(Array) ? joins : [joins]
        left_spec = left._specification if left.is_a?(Quo::RelationBackedQuery)
        right_spec = right._specification if right.is_a?(Quo::RelationBackedQuery)

        base_class = determine_base_class_for_queries(left, right)

        Quo::Composing.composer(
          base_class,
          left.class,
          right.class,
          joins: joins,
          left_spec: left_spec,
          right_spec: right_spec
        ).new(**props)
      end
    end
  end
end
