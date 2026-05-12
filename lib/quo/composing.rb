# frozen_string_literal: true

# rbs_inline: enabled

require_relative "composing/class_strategy_registry"

module Quo
  module Composing
    CLASS_STRATEGY_REGISTRY = ClassStrategyRegistry.new

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

      # @rbs left_instance: Quo::Query
      # @rbs right_instance: Quo::Query | ActiveRecord::Relation | Object & Enumerable[untyped]
      # @rbs joins: Symbol | Hash[Symbol, untyped] | Array[Symbol | Hash[Symbol, untyped]]?
      # @rbs return: Quo::Query
      def merge_instances(left_instance, right_instance, joins: nil)
        page, page_size = inherited_pagination(left_instance, right_instance)
        transformer = inherited_transformer(left_instance, right_instance)

        opts = {left: left_instance, right: right_instance, merge_joins: joins}
        opts[:page] = page if page
        opts[:page_size] = page_size if page_size

        composed = if relation_backed?(left_instance) || relation_backed?(right_instance)
          Quo::ComposedRelationBackedQuery.new(**opts)
        else
          Quo::ComposedCollectionBackedQuery.new(**opts)
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

      # @rbs left: untyped
      # @rbs right: untyped
      # @rbs return: Array[Integer?]
      def inherited_pagination(left, right)
        operand = pagination_source(right) || pagination_source(left)
        return [nil, nil] unless operand
        [operand.page, operand.page_size]
      end

      # @rbs operand: untyped
      # @rbs return: untyped
      def pagination_source(operand)
        return nil unless operand.respond_to?(:page) && operand.respond_to?(:page_size)
        operand.page ? operand : nil
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
