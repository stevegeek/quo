# frozen_string_literal: true

require "test_helper"
require "quo/minitest/helpers"

class Quo::MinitestHelpersTest < ActiveSupport::TestCase
  include Quo::Minitest::Helpers

  test "fake_query" do
    fake_query(CommentNotSpamQuery, results: [1, 2]) do
      q = CommentNotSpamQuery.new(spam_score_threshold: 0.8)
      assert_equal 2, q.results.count
      assert_equal 1, q.results.first
    end
  end
end
