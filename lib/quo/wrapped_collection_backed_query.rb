# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  class WrappedCollectionBackedQuery < Quo.collection_backed_query_base_class
    # @rbs!
    #   @_wrapped: Object & Enumerable[untyped]
    prop :_wrapped, Object, writer: false

    # @rbs override
    def collection
      _wrapped
    end

    # @rbs override
    def inspect
      "#{self.class.name}[#{_wrapped.class.name}]"
    end
  end
end
