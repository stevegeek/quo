# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  # Single concrete class that wraps an existing Enumerable as a
  # Quo::CollectionBackedQuery instance, without allocating a new class.
  #
  # Constructed via `Quo::CollectionBackedQuery.from(enumerable)`. Use this
  # when you want a Quo::Query value for an in-memory collection at a call
  # site, rather than `Quo::CollectionBackedQuery.wrap(enum).new` which
  # allocates an anonymous class per invocation.
  class WrappedCollectionBackedQuery < CollectionBackedQuery
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
