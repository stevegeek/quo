# frozen_string_literal: true

module Quo
  module Utilities
    # 'Smart' wrap Query, ActiveRecord::Relation or a data collection in a Query.
    module Wrap
      def wrap(query_rel_or_data, **options)
        if query_rel_or_data < Quo::Query
          query_rel_or_data
        elsif query_rel_or_data.is_a?(ActiveRecord::Relation)
          Quo::WrappedQuery.wrap(query_rel_or_data, **options)
        else
          Quo::LoadedQuery.wrap(query_rel_or_data)
        end
      end

      def wrap_instance(query_rel_or_data)
        if query_rel_or_data.is_a?(Quo::Query)
          query_rel_or_data
        elsif query_rel_or_data.is_a?(ActiveRecord::Relation)
          Quo::WrappedQuery.wrap(query_rel_or_data).new
        else
          Quo::LoadedQuery.wrap(query_rel_or_data).new
        end
      end
    end
  end
end
