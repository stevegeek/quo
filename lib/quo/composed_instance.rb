# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  # Shared merge logic for value-form (instance-composition) results.
  #
  # In 1.x, instance composition (`q1 + q2`) is implemented by reaching back
  # through class composition (`Composing.composer`) and creating a fresh
  # anonymous Class on every call. In 2.x, instance composition produces a
  # *value* — an instance of one of the two concrete composed classes
  # (`Quo::ComposedRelationBackedQuery` / `Quo::ComposedCollectionBackedQuery`)
  # that holds the operands as instance state.
  #
  # This module factors out the merge logic that's common to both. It expects
  # the host class to expose `_left`, `_right`, and `_joins` as instance
  # methods (they're defined as Literal `prop`s on the host classes).
  module ComposedInstance
    private

    # @rbs return: ActiveRecord::Relation | Enumerable[untyped]
    def merge_left_and_right
      left_rel = unwrap_operand(_left)
      right_rel = unwrap_operand(_right)

      if both_relations?(left_rel, right_rel)
        merge_active_record_relations(left_rel, right_rel)
      elsif left_relation_right_enumerable?(left_rel, right_rel)
        left_rel.to_a + right_rel.to_a
      elsif left_enumerable_right_relation?(left_rel, right_rel) && left_rel.respond_to?(:+)
        left_rel.to_a + right_rel.to_a
      elsif left_rel.respond_to?(:+)
        left_rel + right_rel
      else
        raise ArgumentError, "Cannot merge #{_left.class} with #{_right.class}"
      end
    end

    # Materialise an operand to either an ActiveRecord::Relation or an
    # Enumerable. Each leaf already carries its own props, specs, and
    # transformer; we just ask it for its unpaginated query.
    # @rbs operand: untyped
    # @rbs return: ActiveRecord::Relation | Enumerable[untyped]
    def unwrap_operand(operand)
      case operand
      when Quo::Query
        operand.unwrap_unpaginated
      when ::ActiveRecord::Relation
        operand
      else
        operand
      end
    end

    # @rbs left_rel: ActiveRecord::Relation
    # @rbs right_rel: ActiveRecord::Relation
    # @rbs return: ActiveRecord::Relation
    def merge_active_record_relations(left_rel, right_rel)
      left_rel = left_rel.joins(_joins) if _joins
      left_rel.merge(right_rel)
    end

    # @rbs rel: untyped
    # @rbs return: bool
    def is_relation?(rel)
      rel.is_a?(::ActiveRecord::Relation)
    end

    # @rbs left: untyped
    # @rbs right: untyped
    # @rbs return: bool
    def both_relations?(left, right)
      is_relation?(left) && is_relation?(right)
    end

    # @rbs left: untyped
    # @rbs right: untyped
    # @rbs return: bool
    def left_relation_right_enumerable?(left, right)
      is_relation?(left) && !is_relation?(right)
    end

    # @rbs left: untyped
    # @rbs right: untyped
    # @rbs return: bool
    def left_enumerable_right_relation?(left, right)
      !is_relation?(left) && is_relation?(right)
    end
  end
end
