# frozen_string_literal: true

module Quo
  class EagerQuery < Quo::Query
    # Optionally return the `total_count` option if it has been set.
    # This is useful when the total count is known and not equal to size
    # of wrapped collection.
    def count
      options[:total_count] || super
    end

    # Is this query object paged? (when no total count)
    def paged?
      options[:total_count].nil? && current_page.present?
    end

    def collection
      raise NotImplementedError, "EagerQuery objects must define a 'collection' method"
    end

    def query
      records = collection
      preload_includes(records) if options[:includes]
      records
    end

    def relation?
      false
    end

    def eager?
      true
    end

    private

    def underlying_query
      unwrap_relation(query)
    end

    def unwrap_relation(query)
      query.is_a?(Quo::Query) ? query.unwrap : query
    end

    def preload_includes(records, preload = nil)
      ::ActiveRecord::Associations::Preloader.new(
        records: records,
        associations: preload || options[:includes]
      )
    end
  end
end
