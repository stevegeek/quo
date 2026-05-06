# frozen_string_literal: true

# rbs_inline: enabled

require_relative "composing/class_strategy_registry"
require_relative "composing/instance_strategy_registry"

module Quo
  # Module for composing Query objects
  module Composing
    # The class- and instance-level strategy registries are stateless; share one
    # of each instead of allocating per call.
    CLASS_STRATEGY_REGISTRY = ClassStrategyRegistry.new
    INSTANCE_STRATEGY_REGISTRY = InstanceStrategyRegistry.new

    class << self
      # @rbs chosen_superclass: Class
      # @rbs left_query_class: Class
      # @rbs right_query_class: Class
      # @rbs joins: Symbol | Hash[Symbol, untyped] | Array[Symbol | Hash[Symbol, untyped]]?
      # @rbs left_spec: Quo::RelationBackedQuerySpecification?
      # @rbs right_spec: Quo::RelationBackedQuerySpecification?
      # @rbs return: Class & Quo::ComposedQuery
      def composer(chosen_superclass, left_query_class, right_query_class, joins: nil, left_spec: nil, right_spec: nil)
        strategy = CLASS_STRATEGY_REGISTRY.find_strategy(left_query_class, right_query_class)
        strategy.compose(chosen_superclass, left_query_class, right_query_class, joins: joins, left_spec: left_spec, right_spec: right_spec)
      end

      # Combine two query instances (or an instance and a relation/enumerable)
      # into a value-form composed query.
      #
      # Unlike class composition (`Composing.composer`), this path does NOT
      # allocate a new anonymous class per call. Both possible composed types
      # are concrete singleton classes (`Quo::ComposedRelationBackedQuery` /
      # `Quo::ComposedCollectionBackedQuery`); composition is just a
      # constructor invocation that stores the two operands as instance state.
      #
      # @rbs left_instance: Quo::Query
      # @rbs right_instance: Quo::Query | ActiveRecord::Relation | Object & Enumerable[untyped]
      # @rbs joins: Symbol | Hash[Symbol, untyped] | Array[Symbol | Hash[Symbol, untyped]]?
      # @rbs return: Quo::Query
      def merge_instances(left_instance, right_instance, joins: nil)
        page, page_size = inherited_pagination(left_instance, right_instance)
        transformer = inherited_transformer(left_instance, right_instance)

        composed = if relation_backed?(left_instance) || relation_backed?(right_instance)
          Quo::ComposedRelationBackedQuery.new(_left: left_instance, _right: right_instance, _joins: joins, page: page, page_size: page_size)
        else
          Quo::ComposedCollectionBackedQuery.new(_left: left_instance, _right: right_instance, _joins: joins, page: page, page_size: page_size)
        end

        composed.transform(&transformer) if transformer
        composed
      end

      private

      # @rbs operand: untyped
      # @rbs return: bool
      def relation_backed?(operand)
        operand.is_a?(Quo::RelationBackedQuery) || operand.is_a?(::ActiveRecord::Relation)
      end

      # Pagination inherits from the right operand if set, else from the left.
      # Mirrors the 1.x behaviour where the right operand's `page`/`page_size`
      # would win at instance-level prop fan-out.
      # @rbs left: untyped
      # @rbs right: untyped
      # @rbs return: Array[Integer?]
      def inherited_pagination(left, right)
        page = pick_pagination(:page, right) || pick_pagination(:page, left)
        page_size = pick_pagination(:page_size, right) || pick_pagination(:page_size, left)
        [page, page_size]
      end

      # @rbs key: Symbol
      # @rbs operand: untyped
      # @rbs return: Integer?
      def pick_pagination(key, operand)
        operand.respond_to?(key) ? operand.public_send(key) : nil
      end

      # @rbs left: untyped
      # @rbs right: untyped
      # @rbs return: Proc?
      def inherited_transformer(left, right)
        right_transformer = left_transformer = nil
        right_transformer = right.send(:transformer) if right.is_a?(Quo::Query) && right.transform?
        left_transformer = left.send(:transformer) if left.is_a?(Quo::Query) && left.transform?
        right_transformer || left_transformer
      end
    end
  end
end
