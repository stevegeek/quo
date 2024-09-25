# frozen_string_literal: true

require_relative "../test_helper"
require "quo/minitest/helpers"

class Quo::MinitestHelpersTest < ActiveSupport::TestCase
  include Quo::Minitest::Helpers

  test "stub_query" do
    stub_query(CommentNotSpamQuery, results: [1, 2]) do
      q = CommentNotSpamQuery.new(spam_score_threshold: 0.8)
      assert_equal 2, q.count
      assert_equal 1, q.results.first
    end
  end

  test "mock_query with arguments" do
    mock = mock_query(CommentNotSpamQuery, kwargs: {spam_score_threshold: 0.8}, results: [1, 2])
    stub_query(CommentNotSpamQuery, mock: mock, results: [1, 2]) do
      q = CommentNotSpamQuery.new(spam_score_threshold: 0.8)
      assert_equal 2, q.count
      assert_equal 1, q.results.first
      assert_mock mock
    end
  end

  test "raises when mock args don't match" do
    mock = mock_query(CommentNotSpamQuery, kwargs: {spam_score_threshold: 0.8}, results: [1, 2])
    stub_query(CommentNotSpamQuery, mock: mock, results: [1, 2]) do
      assert_raises(ArgumentError) do
        CommentNotSpamQuery.new
      end
      assert_raises(MockExpectationError) do
        CommentNotSpamQuery.new(spam_score_threshold: 0.9)
      end
    end
  end
end
