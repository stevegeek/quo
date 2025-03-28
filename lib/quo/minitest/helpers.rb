# frozen_string_literal: true

require "minitest/mock"

require_relative "../testing/collection_backed_fake"
require_relative "../testing/relation_backed_fake"

module Quo
  module Minitest
    module Helpers
      def fake_query(query_class, results: [], total_count: nil, page_count: nil, &block)
        # make it so that results of instances of this class return a fake Result object
        # of the right type which returns the results passed in
        if query_class < Quo::CollectionBackedQuery
          klass = Class.new(Quo::Testing::CollectionBackedFake) do
            if query_class < Quo::Preloadable
              include Quo::Preloadable

              def query
                collection
              end
            end
          end
          query_class.stub(:new, ->(**kwargs) {
            klass.new(results: results, total_count: total_count, page_count: page_count)
          }) do
            yield
          end
        elsif query_class < Quo::RelationBackedQuery
          query_class.stub(:new, ->(**kwargs) {
            Quo::Testing::RelationBackedFake.new(results: results, total_count: total_count, page_count: page_count)
          }) do
            yield
          end
        else
          raise ArgumentError, "Not a Query class: #{query_class}"
        end
      end
    end
  end
end
