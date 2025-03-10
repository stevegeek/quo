# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  class CollectionResults < Results
    # @rbs override
    def initialize(query, transformer: nil, total_count: nil)
      raise ArgumentError, "Query must be a CollectionBackedQuery" unless query.is_a?(Quo::CollectionBackedQuery)
      @total_count = total_count
      @query = query
      @configured_query = query.unwrap
      @transformer = transformer
    end

    # Are there any results for this query?
    def exists? #: bool
      @configured_query.present?
    end

    def empty? #: bool
      !exists?
    end

    # Gets the count of all results ignoring the current page and page size (if set).
    # Optionally return the `total_count` option if it has been set.
    # This is useful when the total count is known and not equal to size
    # of wrapped collection.
    # @rbs override
    def total_count #: Integer
      @total_count || @query.unwrap_unpaginated.size
    end

    # Gets the actual count of elements in the page of results (assuming paging is being used, otherwise the count of
    # all results)
    def page_count #: Integer
      @configured_query.size
    end

    # @rbs @query: Quo::CollectionBackedQuery
    # @rbs @transformer: (^(untyped, ?Integer) -> untyped)?
    # @rbs @configured_query: Object & Enumerable[untyped]
  end
end
