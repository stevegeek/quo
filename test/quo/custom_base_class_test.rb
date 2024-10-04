# frozen_string_literal: true

require_relative "../test_helper"

class Quo::CustomBaseClassTest < ActiveSupport::TestCase
  def setup
    a1 = Author.create!(name: "John")
    a2 = Author.create!(name: "Jane")
    p1 = Post.create!(title: "Post 1", author: a1)
    p2 = Post.create!(title: "Post 2", author: a2)
    Comment.create!(post: p1, body: "abc", read: false)
    Comment.create!(post: p2, body: "def", read: false, spam_score: 0.8)

    @q1 = ApplicationRelationQuery.wrap(props: {since_date: Time}) do
      Comment.recent(since_date)
    end
    @q2 = Quo::RelationBackedQuery.wrap(props: {spam_score: Float}) do
      Comment.not_spam(spam_score)
    end
  end

  test "wrapped query inherits from custom base class" do
    assert_kind_of ApplicationRelationQuery, @q1.new(since_date: 1.day.ago)
    assert_equal "relation", @q1.new(since_date: 1.day.ago).hello

    klass = Quo::RelationBackedQuery.wrap(Comment.recent).compose(Comment.not_spam)
    assert_kind_of ApplicationRelationQuery, klass.new
  end
end
