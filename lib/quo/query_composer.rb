# frozen_string_literal: true

module Quo
  class QueryComposer
    def initialize(left, right, joins = nil)
      @left = left
      @right = right
      @joins = joins
    end

    def compose
      combined = merge
      Quo::MergedQuery.new(
        merged_options.merge({scope: combined, source_queries: [left, right]})
      )
    end

    private

    attr_reader :left, :right, :joins

    def merge
      left_rel, right_rel = unwrap_relations
      left_type, right_type = relation_types?
      if both_relations?(left_type, right_type)
        apply_joins(left_rel, joins).merge(right_rel)
      elsif left_relation_right_eager?(left_type, right_type)
        left_rel.to_a + right_rel
      elsif left_eager_right_relation?(left_rel, left_type, right_type)
        left_rel + right_rel.to_a
      elsif both_eager_loaded?(left_rel, left_type, right_type)
        left_rel + right_rel
      else
        raise_error
      end
    end

    def merged_options
      return left.options.merge(right.options) if left.is_a?(Quo::Query) && right.is_a?(Quo::Query)
      return left.options if left.is_a?(Quo::Query)
      return right.options if right.is_a?(Quo::Query)
      {}
    end

    def relation_types?
      [left, right].map do |query|
        if query.is_a?(Quo::Query)
          query.relation?
        else
          query.is_a?(ActiveRecord::Relation)
        end
      end
    end

    def apply_joins(left_rel, joins)
      joins.present? ? left_rel.joins(joins.to_sym) : left_rel
    end

    def both_relations?(left_rel_type, right_rel_type)
      left_rel_type && right_rel_type
    end

    def left_relation_right_eager?(left_rel_type, right_rel_type)
      left_rel_type && !right_rel_type
    end

    def left_eager_right_relation?(left_rel, left_rel_type, right_rel_type)
      !left_rel_type && right_rel_type && left_rel.respond_to?(:+)
    end

    def both_eager_loaded?(left_rel, left_rel_type, right_rel_type)
      !left_rel_type && !right_rel_type && left_rel.respond_to?(:+)
    end

    def unwrap_relations
      [left, right].map { |query| query.is_a?(Quo::Query) ? query.unwrap : query }
    end

    def raise_error
      raise ArgumentError, "Unable to composite queries #{left.class.name} and " \
            "#{right.class.name}. You cannot compose queries where #query " \
            "returns an ActiveRecord::Relation in one and an Enumerable in the other."
    end
  end
end
