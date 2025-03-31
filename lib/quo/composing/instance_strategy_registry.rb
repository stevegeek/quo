# frozen_string_literal: true

require_relative "query_and_relation_strategy"
require_relative "relation_and_query_strategy"
require_relative "query_and_query_strategy"
require_relative "relation_and_relation_strategy"

module Quo
  module Composing
    # Registry for instance composition strategies
    class InstanceStrategyRegistry
      def strategies
        @strategies ||= [
          QueryAndRelationStrategy.new,
          RelationAndQueryStrategy.new,
          QueryAndQueryStrategy.new,
          RelationAndRelationStrategy.new
          # Add more instance strategies as needed
        ]
      end

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
