# frozen_string_literal: true

# rbs_inline: enabled

require_relative "base_strategy"

module Quo
  module Composing
    # Base class for instance composition strategies
    class InstanceStrategy < BaseStrategy
      # @rbs left_instance: Quo::Query | ActiveRecord::Relation | Object & Enumerable[untyped]
      # @rbs right_instance: Quo::Query | ActiveRecord::Relation | Object & Enumerable[untyped]
      # @rbs return: void
      def validate_instances(left_instance, right_instance)
        unless left_instance.is_a?(Quo::Query) || left_instance.is_a?(::ActiveRecord::Relation)
          raise ArgumentError, "Cannot merge, left has incompatible type #{left_instance.class}"
        end

        unless right_instance.is_a?(Quo::Query) || right_instance.is_a?(::ActiveRecord::Relation)
          raise ArgumentError, "Cannot merge, right has incompatible type #{right_instance.class}"
        end
      end

      # @rbs left_query: Quo::Query | ActiveRecord::Relation
      # @rbs right_query: Quo::Query | ActiveRecord::Relation
      # @rbs return: Class
      def determine_base_class_for_queries(left_query, right_query)
        both_relation_backed = left_query.is_a?(Quo::RelationBackedQuery) &&
          right_query.is_a?(Quo::RelationBackedQuery)

        both_relation_backed ? Quo.relation_backed_query_base_class :
                               Quo.collection_backed_query_base_class
      end
    end
  end
end
