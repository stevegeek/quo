# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  class WrappedRelationBackedQuery < Quo.relation_backed_query_base_class
    # @rbs!
    #   @_wrapped: ActiveRecord::Relation
    prop :_wrapped, Object, writer: false

    # @rbs override
    def query
      _wrapped
    end

    # @rbs override
    def inspect
      "#{self.class.name}[#{_wrapped.klass.name}]"
    end
  end
end
