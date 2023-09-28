# frozen_string_literal: true

module Quo
  class LoadedQuery < Quo::EagerQuery
    # TODO: loaded query should only take options that are relavent to the query such as includes, not arbitrary options
    # as you dont need to pass arbitarary params to these!
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
