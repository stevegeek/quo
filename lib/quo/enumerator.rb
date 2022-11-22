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
    def method_missing(method, *args, &block)
      if unwrapped.respond_to?(method)
        debug_callstack
        if block
          unwrapped.send(method, *args) do |*block_args|
            x = block_args.first
            transformed = transformer.present? ? transformer.call(x) : x
            block.call(transformed, *block_args[1..])
          end
        else
          raw = unwrapped.send(method, *args)
          return raw if raw.is_a?(Quo::Enumerator) || raw.is_a?(::Enumerator)
          transform_results(raw)
        end
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      Enumerable.instance_methods.include?(method) || super
    end

    private

    attr_reader :transformer, :unwrapped

    def transform_results(results)
      return results unless transformer.present?

      if results.is_a?(Enumerable)
        results.map.with_index { |item, i| transformer.call(item, i) }
      else
        transformer.call(results)
      end
    end
  end
end
