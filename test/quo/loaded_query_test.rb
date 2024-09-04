# frozen_string_literal: true

require_relative "../test_helper"

class Quo::LoadedQueryTest < ActiveSupport::TestCase
  test "creates a new loaded query object from an array" do
    q = Quo::LoadedQuery.wrap([1, 2, 3]).new
    assert_kind_of Quo::LoadedQuery, q
    assert_equal [1, 2, 3], q.to_a
    assert_equal 3, q.results.size
  end
end
