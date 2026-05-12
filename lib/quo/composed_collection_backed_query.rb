# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  class ComposedCollectionBackedQuery < Quo.collection_backed_query_base_class
    include ComposedInstance

    # @rbs!
    #   @_left: untyped
    #   @_right: untyped
    #   @_joins: untyped
    prop :_left, Object, writer: false
    prop :_right, Object, writer: false
    prop :_joins, _Nilable(Object), default: -> {}, writer: false

    # @rbs override
    def collection
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
