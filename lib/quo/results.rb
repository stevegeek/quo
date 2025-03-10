# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  class Results
    def empty? #: bool
      !exists?
    end

    # Alias for total_count
    def count #: Integer
      total_count
    end

    # Alias for total_count
    def size #: Integer
      total_count
    end

    # Alias for page_count
    def page_size #: Integer
      page_count
    end

    # @rbs &block: (untyped, *untyped) -> untyped
    # @rbs return: Hash[untyped, Array[untyped]]
    def group_by(&block)
      grouped = @configured_query.group_by do |*block_args|
        x = block_args.first
        transformed = transform? ? @transformer.call(x) : x
        block ? block.call(transformed, *(block_args[1..] || [])) : transformed
      end

      grouped.tap do |groups|
        groups.transform_values! do |values|
          @transformer ? values.map { |x| @transformer.call(x) } : values
        end
      end
    end

    # Delegate other enumerable methods to underlying collection but also transform
    # @rbs override
    def method_missing(method, *args, **kwargs, &block)
      return super unless respond_to_missing?(method)

      if block
        @configured_query.send(method, *args, **kwargs) do |*block_args|
          x = block_args.first
          transformed = transform? ? @transformer.call(x) : x
          other_args = block_args[1..] || []
          block.call(transformed, *other_args)
        end
      else
        raw = @configured_query.send(method, *args, **kwargs)
        # FIXME: consider how to handle applying a transformer to a Enumerator...
        return raw if raw.is_a?(Quo::RelationResults) || raw.is_a?(::Enumerator)
        transform_results(raw)
      end
    end

    # @rbs name: Symbol
    # @rbs include_private: bool
    # @rbs return: bool
    def respond_to_missing?(name, include_private = false)
      @configured_query.respond_to?(name, include_private)
    end

    def transform? #: bool
      @transformer.present?
    end

    private

    # @rbs @transformer: (^(untyped, ?Integer) -> untyped)?

    # @rbs results: untyped
    # @rbs return: untyped
    def transform_results(results)
      return results unless transform?

      if results.is_a?(Enumerable)
        results.map.with_index { |item, i| @transformer.call(item, i) }
      else
        @transformer.call(results)
      end
    end
  end
end
