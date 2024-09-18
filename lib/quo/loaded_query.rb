# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  class LoadedQuery < Quo::EagerQuery
    # @rbs data: untyped, props: Symbol => untyped, block: () -> untyped
    # @rbs return: Quo::LoadedQuery
    def self.wrap(data = nil, props: {}, &block)
      klass = Class.new(self)
      if block
        klass.define_method(:query, &block)
      elsif data
        klass.define_method(:query) { data }
      else
        raise ArgumentError, "either a query or a block must be provided"
      end
      # klass.set_temporary_name = "quo::Wrapper" # Ruby 3.3+
      klass
    end

    # @rbs override
    def loaded?
      true
    end
  end
end
