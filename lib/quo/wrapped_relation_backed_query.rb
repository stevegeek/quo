# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  class WrappedRelationBackedQuery < Quo.relation_backed_query_base_class
    # @rbs!
    #   @wrapped: ActiveRecord::Relation
    prop :wrapped, ::ActiveRecord::Relation, writer: false

    # @rbs override
    def query
      wrapped
    end

    # @rbs override
    def inspect
      "#{self.class.name}[#{wrapped.klass.name}]"
    end
  end
end
