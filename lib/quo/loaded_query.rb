# frozen_string_literal: true

module Quo
  class LoadedQuery < Quo::EagerQuery
    def self.wrap(data = nil, props: {}, &block)
      klass = Class.new(self)
      if block_given?
        klass.define_method(:query, &block)
      elsif data
        klass.define_method(:query) { data }
      else
        raise ArgumentError, "either a query or a block must be provided"
      end
      # klass.set_temporary_name = "quo::Wrapper" # Ruby 3.3+
      klass
    end

    def loaded?
      true
    end
  end
end
