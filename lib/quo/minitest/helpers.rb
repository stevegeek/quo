# frozen_string_literal: true

require "minitest/mock"

module Quo
  module Minitest
    module Helpers
      # Stub query takes a block, and will yield to it with the stub on `new` set up.]
      # Optionally, you can provide a mock to use for the fake query, instead of using a CollectionBackedQuery instance.
      def stub_query(query_class, mock: nil, results: [])
        raise "stub_query requires a block" unless block_given?

        fake = if mock
          proc { |*p, **k, &b| mock.new(*p, **k, &b) }
        else
          ::Quo::CollectionBackedQuery.wrap(results).new
        end
        query_class.stub(:new, fake) do
          yield
        end
      end

      # Return a Mock query. This can then be used with `stub_query` if desired.
      # `args`/`kwargs` are optional, and if provided, the mock will expect `new` with the given arguments.
      def mock_query(query_class, args: [], kwargs: nil, results: [])
        query_class_mock = ::Minitest::Mock.new(query_class)
        fake_qo_instance = ::Quo::CollectionBackedQuery.wrap(results).new
        query_class_mock.expect(:new, fake_qo_instance, args, **kwargs)
        query_class_mock
      end
    end
  end
end
