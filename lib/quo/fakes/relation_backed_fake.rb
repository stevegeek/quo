# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  module Fakes
    class RelationBackedFake < Quo.relation_backed_query_base_class
      prop :results, _Any, reader: false
      prop :page_count, _Nilable(Integer), reader: false
      prop :total_count, _Nilable(Integer), reader: false

      def query
        @results
      end

      def results
        klass = Class.new(RelationResults) do
          def page_count
            @query.page_count
          end

          def total_count
            @query.total_count
          end
        end
        klass.new(self)
      end

      def page_count
        @page_count || validated_query.size
      end

      def total_count
        @total_count || validated_query.size
      end

      private

      def validated_query
        query
      end

      def underlying_query
        validated_query
      end

      def configured_query
        validated_query
      end
    end
  end
end
