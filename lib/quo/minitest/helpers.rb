# frozen_string_literal: true

require "minitest/mock"

require_relative "../testing/collection_backed_fake"
require_relative "../testing/relation_backed_fake"
require_relative "../testing/fake_helpers"

module Quo
  module Minitest
    # Test helpers for stubbing query objects in Minitest
    module Helpers
      include Quo::Testing::FakeHelpers

      def fake_query(query_class, results: [], total_count: nil, page_count: nil, &block)
        unless query_class < Quo::Query
          raise ArgumentError, "Not a Query class: #{query_class}"
        end

        klass = build_fake_class(query_class)
        query_class.stub(:new, ->(**kwargs) {
          klass.new(results: results, total_count: total_count, page_count: page_count)
        }) do
          yield
        end
      end
    end
  end
end
