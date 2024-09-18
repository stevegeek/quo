# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  # @rbs inherits Quo::Query
  class EagerQuery < Quo.base_query_class
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
      raise NotImplementedError, "EagerQuery objects must define a 'collection' method"
    end

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
