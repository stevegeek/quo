# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  # @rbs inherits Quo::Query
  class CollectionBackedQuery < Quo.base_query_class
    prop :total_count, _Nilable(Integer), shadow_check: false, reader: false

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

    # TODO: review this, count should be the paged count, while total_count should be the total count
    # Optionally return the `total_count` option if it has been set.
    # This is useful when the total count is known and not equal to size
    # of wrapped collection.
    # @rbs override
    def count
      @total_count || underlying_query.size
    end

    # @rbs override
    def page_count
      configured_query.size
    end

    # Is this query object paged? (when no total count)
    # TODO: review this...
    # @rbs override
    def paged?
      @total_count.nil? && page_index.present?
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
      preload_includes(records) if @_rel_includes
      records
    end

    # @rbs override
    def relation?
      false
    end

    # @rbs override
    def collection?
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
        associations: preload || @_rel_includes
      ).call
    end
  end
end
