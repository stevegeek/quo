# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  module Testing
    class CollectionBackedFake < Quo.collection_backed_query_base_class
      prop :results, _Any, reader: false
      prop :page_count, _Nilable(Integer), reader: false

      def collection
        @results
      end

      def results
        klass = Class.new(CollectionResults) do
          def page_count
            @query.page_count
          end
        end
        klass.new(self)
      end

      def page_count
        @page_count || validated_query.size
      end
    end
  end
end
