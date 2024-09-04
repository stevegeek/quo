# frozen_string_literal: true

require "forwardable"
require_relative "utilities/callstack"

module Quo
  class Results
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
      :count

    def group_by(&block)
      debug_callstack
      grouped = unwrapped.group_by do |*block_args|
        x = block_args.first
        transformed = transformer ? transformer.call(x) : x
        block ? block.call(transformed, *(block_args[1..] || [])) : transformed
      end

      grouped.tap do |groups|
        groups.transform_values! do |values|
          transformer ? values.map { |x| transformer.call(x) } : values
        end
      end
    end

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
          # FIXME: consider how to handle applying a transformer to a Enumerator...
          return raw if raw.is_a?(Quo::Results) || raw.is_a?(::Enumerator)
          transform_results(raw)
        end
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      enumerable_methods_supported.include?(name)
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

    def enumerable_methods_supported
      [:find_each] + Enumerable.instance_methods
    end
  end
end
