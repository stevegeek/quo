# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  class RelationResults < Results
    # @rbs query: Quo::Query
    # @rbs transformer: (^(untyped, ?Integer) -> untyped)?
    # @rbs return: void
    def initialize(query, transformer: nil)
      raise ArgumentError, "Query must be a RelationBackedQuery" unless query.is_a?(Quo::RelationBackedQuery)
      @query = query
      @configured_query = query.unwrap
      @transformer = transformer
    end

    # Are there any results for this query?
    def exists? #: bool
      return @configured_query.exists? if @query.relation?
      @configured_query.present?
    end

    # Gets the count of all results ignoring the current page and page size (if set).
    def total_count #: Integer
      count_query(@query.unwrap_unpaginated)
    end

    # Gets the actual count of elements in the page of results (assuming paging is being used, otherwise the count of
    # all results)
    def page_count #: Integer
      count_query(@configured_query)
    end

    private

    # @rbs @query: Quo::RelationBackedQuery
    # @rbs @configured_query: ActiveRecord::Relation

    # Note we reselect the query as this prevents query errors if the SELECT clause is not compatible with COUNT
    # (SQLException: wrong number of arguments to function COUNT()). We do this in two ways, either with the primary key
    # or with Arel.star. The primary key is the most compatible way to count, but if the query does not have a primary
    # we fallback. The fallback "*" wont work in certain situations though, specifically if we have a limit() on the query
    # which Arel constructs as a subquery. In this case we will get a SQL error as the generated SQL contains
    # `SELECT COUNT(count_column) FROM (SELECT * AS count_column FROM ...) subquery_for_count` where the error is:
    # `ActiveRecord::StatementInvalid: SQLite3::SQLException: near "AS": syntax error`
    # Either way DB engines know how to count efficiently.
    # @rbs query: ActiveRecord::Relation
    # @rbs return: Integer
    def count_query(query)
      pk = query.model.primary_key
      if pk
        query.reselect(pk).count
      else
        query.reselect(Arel.star).count
      end
    end
  end
end
