# frozen_string_literal: true

module Quo
  class QueryComposer
    def initialize(left, right, joins = nil)
      @left = left
      @right = right
      @unwrapped_left = unwrap_relation(left)
      @unwrapped_right = unwrap_relation(right)
      @left_relation = @unwrapped_left.is_a?(::ActiveRecord::Relation)
      @right_relation = @unwrapped_right.is_a?(::ActiveRecord::Relation)
      @joins = joins
    end

    def compose
      Quo::MergedQuery.new(
        merge_left_and_right,
        left,
        right,
        **merged_options
      )
    end

    private

    attr_reader :left, :right, :joins, :unwrapped_left, :unwrapped_right

    def left_relation?
      @left_relation
    end

    def right_relation?
      @right_relation
    end

    def merge_left_and_right
      # FIXME: Skipping type checks here, as not sure how to make this type check with RBS
      __skip__ = if both_relations?
        apply_joins(unwrapped_left, joins).merge(unwrapped_right)
      elsif left_relation_right_enumerable?
        unwrapped_left.to_a + unwrapped_right
      elsif left_enumerable_right_relation?
        unwrapped_left + unwrapped_right.to_a
      else
        unwrapped_left + unwrapped_right
      end
    end

    def merged_options
      return left.options.merge(right.options) if left.is_a?(Quo::Query) && right.is_a?(Quo::Query)
      return left.options if left.is_a?(Quo::Query)
      return right.options if right.is_a?(Quo::Query)
      {}
    end

    def unwrap_relation(query)
      query.is_a?(Quo::Query) ? query.unwrap : query
    end

    def apply_joins(left_rel, joins)
      joins.present? ? left_rel.joins(joins) : left_rel
    end

    def both_relations?
      left_relation? && right_relation?
    end

    def left_relation_right_enumerable?
      left_relation? && !right_relation?
    end

    def left_enumerable_right_relation?
      !left_relation? && right_relation?
    end
  end
end
