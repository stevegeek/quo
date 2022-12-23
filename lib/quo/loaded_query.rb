# frozen_string_literal: true

module Quo
  class LoadedQuery < Quo::EagerQuery
    def initialize(collection, **options)
      @collection = collection
      super(**options)
    end

    def copy(**options)
      self.class.new(@collection, **@options.merge(options))
    end

    private

    attr_reader :collection
  end
end
