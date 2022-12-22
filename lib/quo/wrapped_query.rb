# frozen_string_literal: true

module Quo
  class WrappedQuery < Quo::Query
    class << self
      def call(**options)
        build_from_options(**options).first
      end

      def call!(**options)
        build_from_options(**options).first!
      end

      def build_from_options(**options)
        query = options[:wrapped_query]
        raise ArgumentError, "WrappedQuery needs a scope" unless query
        new(query, **options)
      end
    end

    def initialize(wrapped_query, **options)
      @wrapped_query = wrapped_query
      super(**options)
    end

    def query
      @wrapped_query
    end
  end
end
