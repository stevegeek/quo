# frozen_string_literal: true

module Quo
  module Rspec
    module Helpers
      def stub_query(query_class, with: nil, results: [])
        collection = ::Quo::CollectionBackedQuery.wrap(results)
        unless with.nil?
          return(
            allow(query_class).to receive(:new).with(with) { collection.new }
          )
        end
        allow(query_class).to receive(:new) { collection.new }
      end
    end
  end
end
