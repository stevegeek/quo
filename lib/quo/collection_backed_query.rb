# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  # @rbs inherits Quo::Query
  class CollectionBackedQuery < Quo.base_query_class
    prop :total_count, _Nilable(Integer)

    # Compose is aliased as `+`. Can optionally take `joins` parameters to add joins on merged relation.
    # @rbs right: Quo::Query | ActiveRecord::Relation | Object & Enumerable[untyped]
    # @rbs joins: Symbol | Hash[Symbol, untyped] | Array[Symbol | Hash[Symbol, untyped]]
    def self.compose(right, joins: nil)
      ComposedQuery.composer(Quo::CollectionBackedQuery, self, right, joins: joins)
    end
    singleton_class.alias_method :+, :compose

    # Wrap an enumerable collection or a block that returns an enumerable collection
    # @rbs data: untyped, props: Symbol => untyped, block: () -> untyped
    # @rbs return: Quo::CollectionBackedQuery
    def self.wrap(data = nil, props: {}, &block)
      klass = Class.new(self)
      if block
        klass.define_method(:collection, &block)
      elsif data
        klass.define_method(:collection) { data }
      else
        raise ArgumentError, "either a query or a block must be provided"
      end
      # klass.set_temporary_name = "quo::Wrapper" # Ruby 3.3+
      klass
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

    def results
      Quo::CollectionResults.new(self, transformer: transformer)
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

    # @rbs return: Object & Enumerable[untyped]
    def underlying_query
      query
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
