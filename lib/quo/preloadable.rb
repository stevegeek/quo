# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  module Preloadable
    def self.included(base)
      base.prop :_rel_preload, base._Nilable(base._Any), reader: false, writer: false
    end

    # This implementation of `query` calls `collection` and preloads the includes.
    # @rbs return: Object & Enumerable[untyped]
    def query
      records = collection
      preload_includes(records) if @_rel_preload
      records
    end

    # For use with collections of ActiveRecord models.
    # Configures ActiveRecord::Associations::Preloader to load associations of models in the collection
    # @rbs *options: untyped
    # @rbs return: Quo::Query
    def preload(*options)
      copy(_rel_preload: options)
    end

    # Alias for `preload`
    # @rbs *options: untyped
    # @rbs return: Quo::Query
    def includes(*options)
      preload(*options)
    end

    private

    # @rbs @_rel_preload: untyped?

    # @rbs (untyped records, ?untyped? preload) -> untyped
    def preload_includes(records, preload = nil)
      ::ActiveRecord::Associations::Preloader.new(
        records: records,
        associations: preload || @_rel_preload
      ).call
    end
  end
end
