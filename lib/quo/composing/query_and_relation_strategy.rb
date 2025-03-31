# frozen_string_literal: true

require_relative "instance_strategy"

module Quo
  module Composing
    # Strategy for composing a Query and a Relation
    class QueryAndRelationStrategy < InstanceStrategy
      def applicable?(left, right)
        left.is_a?(Quo::Query) && right.is_a?(::ActiveRecord::Relation)
      end

      def compose(left, right, joins: nil)
        validate_instances(left, right)

        base_class = left.is_a?(Quo::RelationBackedQuery) ?
                     Quo.relation_backed_query_base_class :
                     Quo.collection_backed_query_base_class

        Quo::Composing.composer(base_class, left.class, right, joins: joins).new(**left.to_h)
      end
    end
  end
end
