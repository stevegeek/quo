# frozen_string_literal: true

module Quo
  class EagerQuery < Quo::Query
    def initialize(**options)
      super(**options.merge(scope: Array.wrap(options[:collection])))
    end

    # Optionally return the `total_count` option
    def count
      options[:total_count] || super
    end
    alias_method :total_count, :count
    alias_method :size, :count

    # Is this query object paged? (when no total count)
    def paged?
      options[:total_count].nil? && current_page.present?
    end

    # Return the underlying collection
    def query
      preload_includes(@scope) if options[:includes]
      @scope
    end

    def relation?
      false
    end

    def eager?
      true
    end

    protected

    def preload_includes(records, preload = nil)
      ::ActiveRecord::Associations::Preloader.new(
        records: records,
        associations: preload || options[:includes]
      )
    end
  end
end
