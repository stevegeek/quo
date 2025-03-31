# frozen_string_literal: true

# rbs_inline: enabled

require_relative "composing/class_strategy_registry"
require_relative "composing/instance_strategy_registry"

module Quo
  # Module for composing Query objects
  module Composing
    class << self
      # @rbs chosen_superclass: Class
      # @rbs left_query_class: Class
      # @rbs right_query_class: Class
      # @rbs joins: Symbol | Hash[Symbol, untyped] | Array[Symbol | Hash[Symbol, untyped]]?
      # @rbs left_spec: Quo::RelationBackedQuerySpecification?
      # @rbs right_spec: Quo::RelationBackedQuerySpecification?
      # @rbs return: Class & Quo::ComposedQuery
      def composer(chosen_superclass, left_query_class, right_query_class, joins: nil, left_spec: nil, right_spec: nil)
        registry = ClassStrategyRegistry.new
        strategy = registry.find_strategy(left_query_class, right_query_class)
        strategy.compose(chosen_superclass, left_query_class, right_query_class, joins: joins, left_spec: left_spec, right_spec: right_spec)
      end

      # @rbs left_instance: Quo::Query
      # @rbs right_instance: Quo::Query | ActiveRecord::Relation | Object & Enumerable[untyped]
      # @rbs joins: Symbol | Hash[Symbol, untyped] | Array[Symbol | Hash[Symbol, untyped]]?
      # @rbs return: Quo::ComposedQuery
      def merge_instances(left_instance, right_instance, joins: nil)
        registry = InstanceStrategyRegistry.new
        strategy = registry.find_strategy(left_instance, right_instance)
        strategy.compose(left_instance, right_instance, joins: joins)
      end
    end
  end
end
