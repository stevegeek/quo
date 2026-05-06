# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  # Single concrete class that backs the value form of relation composition
  # (`relation_q1 + relation_q2` between instances).
  #
  # Holds the two operands and an optional joins arg as instance state.
  # No anonymous classes are created at composition time — composition is
  # just `ComposedRelationBackedQuery.new(_left:, _right:, _joins:)`.
  class ComposedRelationBackedQuery < RelationBackedQuery
    include ComposedInstance

    # @rbs!
    #   @_left: untyped
    #   @_right: untyped
    #   @_joins: untyped
    prop :_left,  Object,        writer: false
    prop :_right, Object,        writer: false
    prop :_joins, _Nilable(Object), default: -> { nil }, writer: false

    # @rbs override
    def query
      merge_left_and_right
    end

    # @rbs override
    def inspect
      "#{self.class.name}[#{operand_desc(_left)}, #{operand_desc(_right)}]"
    end

    private

    # @rbs operand: untyped
    # @rbs return: String
    def operand_desc(operand)
      case operand
      when Quo::Query
        operand.class.name || "(anonymous Quo::Query)"
      when ::ActiveRecord::Relation
        operand.klass.name
      else
        operand.class.name || "(anonymous)"
      end
    end
  end
end
