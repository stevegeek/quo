# frozen_string_literal: true

require_relative "composing/class_strategy_registry"
require_relative "composing/instance_strategy_registry"

module Quo
  # Module for composing Query objects
  module Composing
    class << self
      def composer(chosen_superclass, left_query_class, right_query_class, joins: nil, left_spec: nil, right_spec: nil)
        registry = ClassStrategyRegistry.new
        strategy = registry.find_strategy(left_query_class, right_query_class)
        strategy.compose(chosen_superclass, left_query_class, right_query_class, joins: joins, left_spec: left_spec, right_spec: right_spec)
      end

      def merge_instances(left_instance, right_instance, joins: nil)
        registry = InstanceStrategyRegistry.new
        strategy = registry.find_strategy(left_instance, right_instance)
        strategy.compose(left_instance, right_instance, joins: joins)
      end
    end
  end
end
