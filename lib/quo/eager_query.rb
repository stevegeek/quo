# frozen_string_literal: true

module Quo
  class EagerQuery < Quo::Query
    class << self
      def call(**options)
        build_from_options(options).first
      end

      def call!(**options)
        build_from_options(options).first!
      end

      def build_from_options(options)
        collection = options[:collection]
        raise ArgumentError, "EagerQuery needs a collection" unless collection
        new(collection, **options.except(:collection))
      end
    end

    def initialize(collection, **options)
      @collection = Array.wrap(collection)
      super(**options)
    end

    def copy(**options)
      self.class.new(@collection, **@options.merge(options))
    end

    # Optionally return the `total_count` option if it has been set.
    # This is useful when the total count is known and not equal to size
    # of wrapped collection.
    def count
      options[:total_count] || super
    end
    alias_method :total_count, :count
    alias_method :size, :count

    # Is this query object paged? (when no total count)
    def paged?
      options[:total_count].nil? && current_page.present?
    end

    def query
      preload_includes(collection) if options[:includes]
      collection
    end

    def relation?
      false
    end

    def eager?
      true
    end

    private

    attr_reader :collection

    def preload_includes(records, preload = nil)
      ::ActiveRecord::Associations::Preloader.new(
        records: records,
        associations: preload || options[:includes]
      )
    end
  end
end
