# frozen_string_literal: true

module Quo
  module Utilities
    # Combine two query-like or composeable entities:
    # These can be Quo::Query, Quo::MergedQuery, Quo::EagerQuery and ActiveRecord::Relations.
    # See the `README.md` docs for more details.
    module Compose
      def self.included(base)
        base.extend ClassMethods
      end

      # Compose is aliased as `+`. Can optionally take `joins` parameters to add joins on merged relation.
      def merge(right, joins: nil)
        ComposedQuery.merge_instances(self, right, joins: joins)
      end

      alias_method :+, :merge

      module ClassMethods
        def composable_with?(query)
          query.is_a?(Quo::Query) || query.is_a?(ActiveRecord::Relation)
        end

        # Compose is aliased as `+`. Can optionally take `joins` parameters to add joins on merged relation.
        def compose(right, joins: nil)
          ComposedQuery.compose(self, right, joins: joins)
        end

        alias_method :+, :compose
      end
    end
  end
end
