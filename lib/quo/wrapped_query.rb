# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  class WrappedQuery < Quo.base_query_class
    # @rbs query: ActiveRecord::Relation | Quo::Query
    # @rbs props: Hash[Symbol, untyped]
    # @rbs &block: () -> ActiveRecord::Relation | Quo::Query | Object & Enumerable[untyped]
    # @rbs return: Quo::WrappedQuery
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
