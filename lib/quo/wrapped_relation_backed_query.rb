# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  # Single concrete class that wraps an existing ActiveRecord relation as a
  # Quo::RelationBackedQuery instance, without allocating a new class.
  #
  # Constructed via `Quo::RelationBackedQuery.from(relation)`. Use this when
  # you want a Quo::Query value for an AR scope at a call site, rather than
  # `Quo::RelationBackedQuery.wrap(rel).new` which allocates an anonymous
  # class per invocation.
  #
  # Inherits from `Quo.relation_backed_query_base_class` (typically
  # `ApplicationRelationQuery`) so host-application behaviour added to
  # the base class is available on `.from` instances too.
  class WrappedRelationBackedQuery < Quo.relation_backed_query_base_class
    # @rbs!
    #   @_wrapped: ActiveRecord::Relation
    prop :_wrapped, Object, writer: false

    # @rbs override
    def query
      _wrapped
    end

    # @rbs override
    def inspect
      "#{self.class.name}[#{_wrapped.klass.name}]"
    end
  end
end
