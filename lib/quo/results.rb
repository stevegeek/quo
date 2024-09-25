# frozen_string_literal: true

# rbs_inline: enabled

require "forwardable"

module Quo
  class Results
    extend Forwardable

    # @rbs query: Quo::Query
    # @rbs transformer: (^(untyped, ?Integer) -> untyped)?
    # @rbs return: void
    def initialize(query, transformer: nil)
      @query = query
      @unwrapped = query.unwrap
      @transformer = transformer
    end

    # @rbs!
    #   def include?: () -> bool
    #   def member?: () -> bool
    #   def all?: () -> bool
    #   def any?: () -> bool
    #   def none?: () -> bool
    #   def one?: () -> bool
    def_delegators :unwrapped,
      :include?,
      :member?,
      :all?,
      :any?,
      :none?,
      :one?

    def_delegators :query, :count

    # Are there any results for this query?
    def exists? #: bool
      return unwrapped.exists? if query.relation?
      configured_query.present?
    end

    def empty? #: bool
      !exists?
    end

    # @rbs &block: (untyped, *untyped) -> untyped
    # @rbs return: Hash[untyped, Array[untyped]]
    def group_by(&block)
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
    # @rbs override
    def method_missing(method, *args, **kwargs, &block)
      if unwrapped.respond_to?(method)
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

    # @rbs name: Symbol
    # @rbs include_private: bool
    # @rbs return: bool
    def respond_to_missing?(name, include_private = false)
      enumerable_methods_supported.include?(name)
    end

    private

    attr_reader :query #: Quo::Query
    attr_reader :transformer #: (^(untyped, ?Integer) -> untyped)?
    attr_reader :unwrapped #: ActiveRecord::Relation | Object & Enumerable[untyped]

    # @rbs results: untyped
    # @rbs return: untyped
    def transform_results(results)
      return results unless transformer

      if results.is_a?(Enumerable)
        results.map.with_index { |item, i| transformer.call(item, i) }
      else
        transformer.call(results)
      end
    end

    # @rbs return: Array[Symbol]
    def enumerable_methods_supported
      [:find_each] + Enumerable.instance_methods
    end
  end
end
