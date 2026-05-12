# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  class ComposedRelationBackedQuery < Quo.relation_backed_query_base_class
    include ComposedInstance

    # @rbs!
    #   @left: Quo::Query | ActiveRecord::Relation | Enumerable[untyped]
    #   @right: Quo::Query | ActiveRecord::Relation | Enumerable[untyped]
    #   @merge_joins: Symbol | Hash[untyped, untyped] | Array[untyped] | nil
    prop :left, _Union(Quo::Query, Enumerable), writer: false
    prop :right, _Union(Quo::Query, Enumerable), writer: false
    prop :merge_joins, _Nilable(_Union(Symbol, Hash, Array)), default: -> {}, writer: false

    # @rbs override
    def query
      merge_left_and_right
    end

    # @rbs override
    def inspect
      "#{self.class.name}[#{operand_desc(left)}, #{operand_desc(right)}]"
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
