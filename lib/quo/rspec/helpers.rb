# frozen_string_literal: true

module Quo
  module Rspec
    module Helpers
      def stub_query(query_class, options = {})
        results = options.fetch(:results, [])
        with = options[:with]
        unless with.nil?
          return(
            allow(query_class).to receive(:new)
                                    .with(with) { ::Quo::CollectionBackedQuery.new(results) }
          )
        end
        allow(query_class).to receive(:new) { ::Quo::CollectionBackedQuery.new(results) }
      end
    end
  end
end
