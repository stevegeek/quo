# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  class WrappedCollectionBackedQuery < Quo.collection_backed_query_base_class
    # @rbs!
    #   @wrapped: Enumerable[untyped]
    prop :wrapped, Enumerable, writer: false

    # @rbs override
    def collection
      wrapped
    end

    # @rbs override
    def inspect
      "#{self.class.name}[#{wrapped.class.name}]"
    end
  end
end
