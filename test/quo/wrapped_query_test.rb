# frozen_string_literal: true

require_relative "../test_helper"

class Quo::WrappedQueryTest < ActiveSupport::TestCase
  test "it wraps an ActiveRecord relation" do
    query = Quo::WrappedQuery.wrap do
      Comment.not_spam
    end

    assert_equal Comment.not_spam.to_sql, query.new.to_sql
  end

  test "it wraps an ActiveRecord relation as argument" do
    query = Quo::WrappedQuery.wrap(Comment.not_spam)
    assert_equal Comment.not_spam.to_sql, query.new.to_sql
  end

  test "it wraps an ActiveRecord relation with props" do
    query = Quo::WrappedQuery.wrap(props: {spam_score: Literal::Types::FloatType.new(0...1.0)}) do
      Comment.not_spam(spam_score)
    end

    assert_equal Comment.not_spam.to_sql, query.new(spam_score: 0.5).to_sql
    assert query < Quo::WrappedQuery
  end

  test "it raises when wrapping an ActiveRecord relation with prop that shadows a method" do
    assert_raises ArgumentError do
      Quo::WrappedQuery.wrap(props: {to_sql: Literal::Types::FloatType.new(0...1.0)}) do
        Comment.not_spam
      end
    end
  end

  test "it wraps a query object" do
    query = Quo::WrappedQuery.wrap(props: {threshold: Float}) do
      CommentNotSpamQuery.new(spam_score_threshold: threshold)
    end

    assert_equal CommentNotSpamQuery.new(spam_score_threshold: 0.9).to_sql, query.new(threshold: 0.9).to_sql
  end
end
