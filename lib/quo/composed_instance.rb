# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  module ComposedInstance
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
