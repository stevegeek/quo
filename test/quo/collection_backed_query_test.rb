# frozen_string_literal: true

require_relative "../test_helper"

class Quo::CollectionBackedQueryTest < ActiveSupport::TestCase
  test "creates a new loaded query object from an array" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    assert_kind_of Quo::CollectionBackedQuery, q
    assert_equal [1, 2, 3], q.to_a
    assert_equal 3, q.results.size
  end

  test "#copy makes a copy of an query object with different options" do
    klass = Class.new(Quo::CollectionBackedQuery) do
      prop :foo, Integer

      def collection
        [1, 2, 3]
      end
    end
    q = klass.new(foo: 1)
    q_copy = q.copy(foo: 2)
    assert_kind_of Quo::CollectionBackedQuery, q_copy
    assert_not_equal q, q_copy
    assert_equal 2, q_copy.options[:foo]
  end
end
