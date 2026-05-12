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
    # Copy a composed instance with overrides.
    #
    # The composed instance's own props (`_left`, `_right`, `_joins`,
    # `_specification`, `page`, `page_size`) are passed straight through to
    # the standard Literal copy.
    #
    # Any *other* override is treated as a fan-out into the operand tree:
    # we walk right-first, recursing into composed operands, and apply the
    # override to the first reachable Quo::Query operand that declares the
    # property. If no operand declares it, an ArgumentError is raised — the
    # same surface as a normal `copy(unknown_prop:)` would produce.
    #
    # This is O(tree size) per fan override, not free. It is intended for
    # call-site convenience, not for hot paths.
    # @rbs **overrides: untyped
    # @rbs return: Quo::Query
    def copy(**overrides)
      return super if overrides.empty?

      own_keys = own_property_names
      own_overrides = overrides.slice(*own_keys)
      fan_overrides = overrides.except(*own_keys)

      result = own_overrides.empty? ? self : super(**own_overrides)
      fan_overrides.each do |key, value|
        result = result.send(:fan_override, key, value)
      end
      result
    end

    private

    # Walks the operand tree and returns a copy of `self` with the override
    # applied to *every* reachable Quo::Query operand that declares the prop.
    # Conceptually, the composed query exposes one logical `prop` — when
    # you copy with a new value, it lands everywhere that prop lives.
    # Recurses into composed operands.
    #
    # The re-entries below use own-prop-only overrides (`_right:` /
    # `_left:`), which take the no-fan-out branch in `copy` — no infinite
    # recursion.
    # @rbs prop_name: Symbol
    # @rbs value: untyped
    # @rbs return: Quo::Query
    def fan_override(prop_name, value)
      right_match = operand_accepts?(_right, prop_name)
      left_match = operand_accepts?(_left, prop_name)
      unless right_match || left_match
        raise ArgumentError, "unknown property #{prop_name.inspect} on #{self.class}"
      end

      result = self
      if right_match
        result = result.copy(_right: apply_to_operand(_right, prop_name, value))
      end
      if left_match
        result = result.copy(_left: apply_to_operand(_left, prop_name, value))
      end
      result
    end

    # @rbs return: Array[Symbol]
    def own_property_names
      self.class.literal_properties.properties_index.keys
    end

    # Does `operand` (or any of its descendants if composed) declare
    # `prop_name` as a Literal prop?
    # @rbs operand: untyped
    # @rbs prop_name: Symbol
    # @rbs return: bool
    def operand_accepts?(operand, prop_name)
      case operand
      when Quo::ComposedInstance
        operand.send(:operand_accepts?, operand._right, prop_name) ||
          operand.send(:operand_accepts?, operand._left, prop_name)
      when Quo::Query
        operand.class.literal_properties.properties_index.key?(prop_name)
      else
        false
      end
    end

    # Apply `prop_name => value` to the operand, returning a new operand.
    # Recurses into composed operands so the override lands on the actual
    # leaf that declares it (right-first within the sub-tree).
    # @rbs operand: untyped
    # @rbs prop_name: Symbol
    # @rbs value: untyped
    # @rbs return: untyped
    def apply_to_operand(operand, prop_name, value)
      case operand
      when Quo::ComposedInstance
        operand.send(:fan_override, prop_name, value)
      when Quo::Query
        operand.copy(prop_name => value)
      end
    end

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
