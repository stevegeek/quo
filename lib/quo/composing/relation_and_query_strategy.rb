# frozen_string_literal: true

# rbs_inline: enabled

require_relative "instance_strategy"

module Quo
  module Composing
    # Strategy for composing a Relation and a Query
    class RelationAndQueryStrategy < InstanceStrategy
      # @rbs override
      def applicable?(left, right)
        left.is_a?(::ActiveRecord::Relation) && right.is_a?(Quo::Query)
      end

      # @rbs override
      def compose(left, right, joins: nil)
        validate_instances(left, right)

        base_class = right.is_a?(Quo::RelationBackedQuery) ?
                     Quo.relation_backed_query_base_class :
                     Quo.collection_backed_query_base_class

        Quo::Composing.composer(base_class, left, right.class, joins: joins).new(**right.to_h)
      end
    end
  end
end
