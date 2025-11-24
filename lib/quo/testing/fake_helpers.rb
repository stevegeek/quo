# frozen_string_literal: true

# rbs_inline: enabled

module Quo
  module Testing
    # Shared helpers for creating fake query objects in tests
    module FakeHelpers
      private

      # @rbs query_class: Class
      # @rbs return: Class
      def build_fake_class(query_class)
        if query_class < Quo::CollectionBackedQuery
          Class.new(Quo::Testing::CollectionBackedFake) do
            if query_class < Quo::Preloadable
              include Quo::Preloadable

              def query
                collection
              end
            end
          end
        else
          Quo::Testing::RelationBackedFake
        end
      end
    end
  end
end
