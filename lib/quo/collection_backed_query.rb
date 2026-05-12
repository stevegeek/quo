# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  # Query object backed by in-memory collections
  class CollectionBackedQuery < Query
    prop :total_count, _Nilable(Integer), reader: false

    # @rbs data: Enumerable[untyped] | Quo::CollectionBackedQuery
    # @rbs props: Hash[Symbol, untyped]
    # @rbs &block: ? () -> Enumerable[untyped]
    # @rbs return: Quo::CollectionBackedQuery
    def self.wrap(data = nil, props: {}, &block)
      raise ArgumentError, "either a query or a block must be provided" unless data || block

      if data && !(data.is_a?(::Enumerable) || data.is_a?(Quo::CollectionBackedQuery))
        raise ArgumentError,
          "Quo::CollectionBackedQuery.wrap requires an Enumerable or a Quo::CollectionBackedQuery instance; got #{data.class}. " \
          "Use Quo::RelationBackedQuery.wrap or Quo::RelationBackedQuery.from for ActiveRecord relations."
      end

      klass = Class.new(self)
      define_props_on_class(klass, props)
      if block
        klass.define_method(:collection, &block)
      else
        klass.define_method(:collection) { data }
      end
      klass
    end

    # @rbs enumerable: Enumerable[untyped]
    # @rbs return: Quo::WrappedCollectionBackedQuery
    def self.from(enumerable)
      Quo::WrappedCollectionBackedQuery.new(wrapped: enumerable)
    end

    # @rbs return: Object & Enumerable[untyped]
    def collection
      raise NotImplementedError, "Collection backed query objects must define a 'collection' method"
    end

    # The default implementation of `query` just calls `collection`, however you can also
    # override this method to return an ActiveRecord::Relation or any other query-like object as usual in a Query object.
    # @rbs return: Object & Enumerable[untyped]
    def query
      collection
    end

    def results #: Quo::Results
      Quo::CollectionResults.new(self, transformer: transformer, total_count: @total_count)
    end

    # @rbs override
    def relation?
      false
    end

    # @rbs override
    def collection?
      true
    end

    # @rbs override
    def to_collection
      self
    end

    private

    def validated_query
      query
    end

    # @rbs return: Object & Enumerable[untyped]
    def underlying_query
      validated_query
    end

    # The configured query is the underlying query with paging
    def configured_query #: Object & Enumerable[untyped]
      q = underlying_query
      return q unless paged?

      if q.respond_to?(:[])
        q[offset, sanitised_page_size]
      else
        q
      end
    end
  end
end
