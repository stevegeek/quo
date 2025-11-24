# frozen_string_literal: true

require_relative "../testing/collection_backed_fake"
require_relative "../testing/relation_backed_fake"
require_relative "../testing/fake_helpers"

module Quo
  module Rspec
    # Test helpers for stubbing query objects in RSpec
    module Helpers
      include Quo::Testing::FakeHelpers

      def fake_query(query_class, with: nil, results: [], total_count: nil, page_count: nil, &block)
        unless query_class < Quo::Query
          raise ArgumentError, "Not a Query class: #{query_class}"
        end

        klass = build_fake_class(query_class)
        fake = ->(*kwargs) {
          klass.new(results: results, total_count: total_count, page_count: page_count)
        }
        expectation = allow(query_class).to receive(:new)
        expectation = expectation.with(with) if with
        expectation.and_invoke(fake)
      end
    end
  end
end
