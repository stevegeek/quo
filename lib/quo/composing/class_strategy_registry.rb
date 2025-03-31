# frozen_string_literal: true

# rbs_inline: enabled

require_relative "query_classes_strategy"

module Quo
  module Composing
    # Registry for class composition strategies
    class ClassStrategyRegistry
      # @rbs return: Array[Quo::Composing::BaseStrategy]
      def strategies
        @strategies ||= [
          QueryClassesStrategy.new
          # Add more class strategies as needed
        ]
      end

      # @rbs left: Class
      # @rbs right: Class
      # @rbs return: Quo::Composing::BaseStrategy
      def find_strategy(left, right)
        strategy = strategies.find { |s| s.applicable?(left, right) }
        unless strategy
          raise ArgumentError, "No class composition strategy found for #{left.class} and #{right.class}"
        end
        strategy
      end
    end
  end
end
