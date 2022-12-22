# frozen_string_literal: true

module Quo
  class MergedQuery < Quo::Query
    class << self
      def call(**options)
        build_from_options(options).first
      end

      def call!(**options)
        build_from_options(options).first!
      end

      def build_from_options(options)
        merged_query = options[:merged_query]
        left = options[:left]
        right = options[:right]
        raise ArgumentError, "MergedQuery needs the merged result and operands" unless merged_query && left && right
        new(merged_query, left, right, **options)
      end
    end

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

    def to_s
      "Quo::MergedQuery[#{operand_desc(left)}, #{operand_desc(right)}]"
    end

    private

    attr_reader :left, :right

    def operand_desc(operand)
      if operand.is_a? Quo::MergedQuery
        operand.to_s
      else
        operand.class.name || "(anonymous)"
      end
    end
  end
end
