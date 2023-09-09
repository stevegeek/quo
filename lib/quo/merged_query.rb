# frozen_string_literal: true

module Quo
  class MergedQuery < Quo::Query
    def initialize(merged_query, left, right, **options)
      @merged_query = merged_query
      @left = left
      @right = right
      super(**options)
    end

    def query
      @merged_query
    end

    def copy(**options)
      self.class.new(query, left, right, **@options.merge(options))
    end

    def inspect
      "Quo::MergedQuery[#{operand_desc(left)}, #{operand_desc(right)}]"
    end

    private

    attr_reader :left, :right

    def operand_desc(operand)
      if operand.is_a? Quo::MergedQuery
        operand.inspect
      else
        operand.class.name || "(anonymous)"
      end
    end
  end
end
