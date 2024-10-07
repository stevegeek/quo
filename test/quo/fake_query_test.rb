# frozen_string_literal: true

require_relative "../test_helper"
require "quo/minitest/helpers"

class Quo::FakeQueryTest < ActiveSupport::TestCase
  include Quo::Minitest::Helpers

  def create_query_class
    Class.new(Quo::CollectionBackedQuery) do
      include Quo::Preloadable

      def collection
        [1, 2, 3]
      end
    end
  end

  test "RelationBackedFake acts like a RelationBackedQuery" do
    fake_query(NewCommentsForAuthorQuery, results: [1, 2]) do
      q = NewCommentsForAuthorQuery.new(author_id: 1)
      assert q.results.is_a?(Quo::RelationResults)
      assert q.is_a?(Quo::RelationBackedQuery)
      assert_equal "relation", q.hello
      assert_equal 2, q.results.count
      assert_equal 1, q.results.first
      assert_nothing_raised do
        q.includes(:foo).order(:bar).limit(10).preload(:x).results.first
      end
    end
  end

  test "CollectionBackedFake acts like a CollectionBackedQuery" do
    klass = create_query_class
    fake_query(klass, results: [1, 2]) do
      q = klass.new
      assert q.results.is_a?(Quo::CollectionResults)
      assert q.is_a?(Quo::CollectionBackedQuery)
      assert_equal "collection", q.hello
      assert_equal 2, q.results.count
      assert_equal 1, q.results.first
      assert_nothing_raised do
        q.preload(:x).results.first
      end
    end
  end
end
