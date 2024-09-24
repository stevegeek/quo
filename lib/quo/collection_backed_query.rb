# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  # @rbs inherits Quo::Query
  class CollectionBackedQuery < Quo.base_query_class
    # Wrap an enumerable collection or a block that returns an enumerable collection
    # @rbs data: untyped, props: Symbol => untyped, block: () -> untyped
    # @rbs return: Quo::CollectionBackedQuery
    def self.wrap(data = nil, props: {}, &block)
      klass = Class.new(self)
      if block
        klass.define_method(:query, &block)
      elsif data
        klass.define_method(:query) { data }
      else
        raise ArgumentError, "either a query or a block must be provided"
      end
      # klass.set_temporary_name = "quo::Wrapper" # Ruby 3.3+
      klass
    end

    # Optionally return the `total_count` option if it has been set.
    # This is useful when the total count is known and not equal to size
    # of wrapped collection.
    # @rbs override
    def count
      options[:total_count] || underlying_query.count
    end

    # @rbs override
    def page_count
      configured_query.count
    end

    # Is this query object paged? (when no total count)
    # @rbs override
    def paged?
      options[:total_count].nil? && page_index.present?
    end

    # @rbs return: Object & Enumerable[untyped]
    def collection
      raise NotImplementedError, "Collection backed query objects must define a 'collection' method"
    end

    # The default implementation of `query` calls `collection` and preloads the includes, however you can also
    # override this method to return an ActiveRecord::Relation or any other query-like object as usual in a Query object.
    # @rbs return: Object & Enumerable[untyped]
    def query
      records = collection
      preload_includes(records) if options[:includes]
      records
    end

    # @rbs override
    def relation?
      false
    end

    # @rbs override
    def eager?
      true
    end

    private

    # @rbs override
    def underlying_query
      unwrap_relation(query)
    end

    # @rbs (untyped records, ?untyped? preload) -> untyped
    def preload_includes(records, preload = nil)
      ::ActiveRecord::Associations::Preloader.new(
        records: records,
        associations: preload || options[:includes]
      ).call
    end
  end
end
