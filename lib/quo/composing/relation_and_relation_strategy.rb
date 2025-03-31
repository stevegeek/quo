# frozen_string_literal: true

require_relative "instance_strategy"

module Quo
  module Composing
    # Strategy for composing two Relations
    class RelationAndRelationStrategy < InstanceStrategy
      def applicable?(left, right)
        left.is_a?(::ActiveRecord::Relation) && right.is_a?(::ActiveRecord::Relation)
      end

      def compose(left, right, joins: nil)
        validate_instances(left, right)
        Quo::Composing.composer(Quo.relation_backed_query_base_class, left, right, joins: joins).new
      end
    end
  end
end
