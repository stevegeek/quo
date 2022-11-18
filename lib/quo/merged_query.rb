# frozen_string_literal: true

module Quo
  class MergedQuery < Quo::Query
    def initialize(options, source_queries = [])
      @source_queries = source_queries
      super(**options)
    end

    def query
      @scope
    end

    def to_s
      left = operand_desc(source_queries_left)
      right = operand_desc(source_queries_right)
      "Quo::MergedQuery[#{left}, #{right}]"
    end

    private

    def source_queries_left
      source_queries&.first
    end

    def source_queries_right
      source_queries&.last
    end

    attr_reader :source_queries

    def operand_desc(operand)
      return unless operand
      if operand.is_a? Quo::MergedQuery
        operand.to_s
      else
        operand.class.name
      end
    end
  end
end
