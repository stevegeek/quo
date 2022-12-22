# frozen_string_literal: true

require_relative "../test_helper"

class Quo::EagerQueryTest < ActiveSupport::TestCase
  test "#copy makes a copy of an eager query object with different options" do
    q = Quo::EagerQuery.new([1, 2, 3], foo: 1)
    q_copy = q.copy(foo: 2)
    assert_instance_of Quo::EagerQuery, q_copy
    assert_not_equal q, q_copy
    assert_equal 2, q_copy.instance_variable_get(:@options)[:foo]
  end
end
