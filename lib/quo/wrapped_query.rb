# frozen_string_literal: true

module Quo
  class WrappedQuery < Quo::Query
    def initialize(wrapped_query, **options)
      @wrapped_query = wrapped_query
      super(**options)
    end

    def copy(**options)
      self.class.new(query, **@options.merge(options))
    end

    def query
      @wrapped_query
    end
  end
end
