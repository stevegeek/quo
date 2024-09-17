# frozen_string_literal: true

module Quo
  class WrappedQuery < Quo.base_query_class
    def self.wrap(query = nil, props: {}, &block)
      klass = Class.new(self) do
        props.each do |name, type|
          prop name, type
        end
      end
      if block
        klass.define_method(:query, &block)
      elsif query
        klass.define_method(:query) { query }
      else
        raise ArgumentError, "either a query or a block must be provided"
      end
      # klass.set_temporary_name = "quo::Wrapper" # Ruby 3.3+
      klass
    end
  end
end
