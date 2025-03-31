# frozen_string_literal: true

# rbs_inline: enabled

require_relative "query_and_relation_strategy"
require_relative "relation_and_query_strategy"
require_relative "query_and_query_strategy"
require_relative "relation_and_relation_strategy"

module Quo
  module Composing
    # Registry for instance composition strategies
    class InstanceStrategyRegistry
      # @rbs return: Array[Quo::Composing::BaseStrategy]
      def strategies
        @strategies ||= [
          QueryAndRelationStrategy.new,
          RelationAndQueryStrategy.new,
          QueryAndQueryStrategy.new,
          RelationAndRelationStrategy.new
          # Add more instance strategies as needed
        ]
      end

      # @rbs left: Quo::Query | ActiveRecord::Relation | Object & Enumerable[untyped]
      # @rbs right: Quo::Query | ActiveRecord::Relation | Object & Enumerable[untyped]
      # @rbs return: Quo::Composing::BaseStrategy
      def find_strategy(left, right)
        strategy = strategies.find { |s| s.applicable?(left, right) }
        unless strategy
          raise ArgumentError, "No instance composition strategy found for #{left.class} and #{right.class}"
        end
        strategy
      end
    end
  end
end
