# frozen_string_literal: true

module Quo
  module Utilities
    # Wrap a ActiveRecord::Relation or data collection in a Query.
    #
    # If the passed in object is already a Query object then just return it or copy it if new options are passed in.
    # Otherwise if a Relation wrap it in a new Query object or else in an EagerQuery .
    module Wrap
      def wrap(query_rel_or_data, **options)
        if query_rel_or_data.is_a? Quo::Query
          return options.present? ? query_rel_or_data.copy(**options) : query_rel_or_data
        end

        if query_rel_or_data.is_a? ActiveRecord::Relation
          Quo::WrappedQuery.new(query_rel_or_data, **options)
        else
          Quo::EagerQuery.new(**options.merge(collection: query_rel_or_data))
        end
      end
    end
  end
end
