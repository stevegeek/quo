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

      # Compose is aliased as `+`. Can optionally take `joins()` parameters to perform a joins before the merge
      def compose(right, joins: nil)
        self.class.compose(self, right, joins: joins).compose
      end

      alias_method :+, :compose

      module ClassMethods
        def compose(left, right, joins: nil)
          MergedQuery.compose(left, right, joins: joins)
        end

        def composable_with?(query)
          query.is_a?(Quo::Query) || query.is_a?(ActiveRecord::Relation)
        end
      end
    end
  end
end
