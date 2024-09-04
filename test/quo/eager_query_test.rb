# frozen_string_literal: true

require_relative "../test_helper"

class Quo::EagerQueryTest < ActiveSupport::TestCase
  test "#copy makes a copy of an eager query object with different options" do
    klass = Class.new(Quo::EagerQuery) do
      prop :foo, Integer

      def collection
        [1, 2, 3]
      end
    end
    q = klass.new(foo: 1)
    q_copy = q.copy(foo: 2)
    assert_kind_of Quo::EagerQuery, q_copy
    assert_not_equal q, q_copy
    assert_equal 2, q_copy.options[:foo]
  end
end
