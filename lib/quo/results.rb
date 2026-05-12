# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  # Base results wrapper providing enumeration with optional transformation
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

    FILTER_METHODS = %i[
      select filter find_all reject
      find detect
      take_while drop_while
      sort_by min_by max_by
      uniq
    ].to_set.freeze

    PAIR_FILTER_METHODS = %i[partition minmax_by].to_set.freeze

    PASSTHROUGH_METHODS = %i[
      any? all? none? one? include? member?
      count tally sum
      each_with_object inject reduce
      map collect flat_map collect_concat filter_map
    ].to_set.freeze

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
        raw = @configured_query.send(method, *args, **kwargs) do |*block_args|
          x = block_args.first
          transformed = transform? ? @transformer.call(x) : x
          other_args = block_args[1..] || []
          block.call(transformed, *other_args)
        end
        return raw if PASSTHROUGH_METHODS.include?(method)
        return transform_pair(raw) if PAIR_FILTER_METHODS.include?(method)
        return transform_results(raw) if FILTER_METHODS.include?(method)
        raw
      else
        raw = @configured_query.send(method, *args, **kwargs)
        return raw if raw.is_a?(Quo::RelationResults) || raw.is_a?(::Enumerator)
        return raw if PASSTHROUGH_METHODS.include?(method)
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

    # @rbs pair: untyped
    # @rbs return: untyped
    def transform_pair(pair)
      return pair unless transform?
      pair.map { |part| transform_results(part) }
    end
  end
end
