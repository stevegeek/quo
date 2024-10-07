# frozen_string_literal: true

require_relative "../testing/collection_backed_fake"
require_relative "../testing/relation_backed_fake"

module Quo
  module Rspec
    module Helpers
      def fake_query(query_class, with: nil, results: [], total_count: nil, page_count: nil, &block)
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
          fake = ->(*kwargs) {
            klass.new(results: results, total_count: total_count, page_count: page_count)
          }
          expectation = allow(query_class).to receive(:new)
          expectation = expectation.with(with) if with
          expectation.and_invoke(fake)
        elsif query_class < Quo::RelationBackedQuery
          fake = ->(*kwargs) {
            Quo::Testing::RelationBackedFake.new(results: results, total_count: total_count, page_count: page_count)
          }
          expectation = allow(query_class).to receive(:new)
          expectation = expectation.with(with) if with
          expectation.and_invoke(fake)
        else
          raise ArgumentError, "Not a Query class: #{query_class}"
        end
      end
    end
  end
end
