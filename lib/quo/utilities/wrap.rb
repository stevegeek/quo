# frozen_string_literal: true

module Quo
  module Utilities
    module Wrap
      # Wrap a relation in a Query. If the passed in object is already a query object then just return it
      def wrap(query_rel_or_data, **options)
        if query_rel_or_data.is_a?(Quo::Query) && options.present?
          return query_rel_or_data.copy(**options)
        end
        return query_rel_or_data if query_rel_or_data.is_a? Quo::Query
        if query_rel_or_data.is_a? ActiveRecord::Relation
          return new(**options.merge(scope: query_rel_or_data))
        end
        Quo::EagerQuery.new(**options.merge(collection: query_rel_or_data))
      end
    end
  end
end
