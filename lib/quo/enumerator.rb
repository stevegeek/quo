# frozen_string_literal: true

require "forwardable"
require_relative "./utilities/callstack"

module Quo
  class Enumerator
    extend Forwardable
    include Quo::Utilities::Callstack

    def initialize(query, transformer: nil)
      @query = query
      @unwrapped = query.unwrap
      @transformer = transformer
    end

    def_delegators :unwrapped,
      :include?,
      :member?,
      :all?,
      :any?,
      :none?,
      :one?,
      :tally,
      :count,
      :group_by,
      :partition,
      :slice_before,
      :slice_after,
      :slice_when,
      :chunk,
      :chunk_while,
      :sum,
      :zip

    # Delegate other enumerable methods to underlying collection but also transform
    def method_missing(method, *args, **kwargs, &block)
      if unwrapped.respond_to?(method)
        debug_callstack
        if block
          unwrapped.send(method, *args, **kwargs) do |*block_args|
            x = block_args.first
            transformed = transformer ? transformer.call(x) : x
            other_args = block_args[1..] || []
            block.call(transformed, *other_args)
          end
        else
          raw = unwrapped.send(method, *args, **kwargs)
          return raw if raw.is_a?(Quo::Enumerator) || raw.is_a?(::Enumerator)
          transform_results(raw)
        end
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      Enumerable.instance_methods.include?(name)
    end

    private

    attr_reader :transformer, :unwrapped

    def transform_results(results)
      return results unless transformer

      if results.is_a?(Enumerable)
        results.map.with_index { |item, i| transformer.call(item, i) }
      else
        transformer.call(results)
      end
    end
  end
end
