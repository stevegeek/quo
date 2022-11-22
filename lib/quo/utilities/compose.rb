# frozen_string_literal: true

module Quo
  module Utilities
    module Compose
      # Combine two query-like or composeable entities:
      # These can be Quo::Query, Quo::MergedQuery, Quo::EagerQuery and ActiveRecord::Relations.
      # See the `README.md` docs for more details.
      def compose(query1, query2, joins = nil)
        Quo::QueryComposer.new(query1, query2, joins).compose
      end

      # Determines if the object `query` is something which can be composed with query objects
      def composable_with?(query)
        query.is_a?(Quo::Query) || query.is_a?(ActiveRecord::Relation)
      end
    end
  end
end
