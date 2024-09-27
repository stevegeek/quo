# frozen_string_literal: true

require_relative "../test_helper"

class Quo::ResultsTest < ActiveSupport::TestCase
  def setup
    a1 = Author.create!(name: "John")
    a2 = Author.create!(name: "Jane")
    p1 = Post.create!(title: "Post 1", author: a1)
    p2 = Post.create!(title: "Post 2", author: a2)
    Comment.create!(post: p1, body: "abc", read: false)
    Comment.create!(post: p2, body: "def", read: false)
  end

  test "#each" do
    e = Quo::Results.new(UnreadCommentsQuery.new)
    a = []
    e.each { |c| a << c.body }
    assert_kind_of Quo::Results, e
    assert_equal ["abc", "def"], a
    assert_kind_of Comment, e.first
  end

  test "#map" do
    mapped = Quo::Results.new(UnreadCommentsQuery.new).map.with_index do |c, i|
      c.body = "hello #{i} world"
      c
    end
    assert_equal ["hello 0 world", "hello 1 world"], mapped.map(&:body)

    # FIXME: consider how to handle applying a transformer to a Enumerator...
    # t = ->(v, i) {
    #   v.body = 100 + i
    #   v
    # }
    # mapped = Quo::Results.new(UnreadCommentsQuery.new, transformer: t).map.with_index do |c, i|
    #   c.body = "#{c.body} - #{i}"
    #   c
    # end
    # assert_equal ["100 - 0", "101 - 1"], mapped.map(&:body)
  end

  test "#take(2)" do
    taken = Quo::Results.new(UnreadCommentsQuery.new).take(2)
    assert_equal ["abc", "def"], taken.map(&:body)

    t = ->(v, i) {
      v.body = i
      v
    }
    taken = Quo::Results.new(UnreadCommentsQuery.new, transformer: t).take(2)
    assert_equal ["0", "1"], taken.map(&:body)
  end

  test "#exists?" do
    results = Quo::Results.new(UnreadCommentsQuery.new)
    assert results.exists?
    results = Quo::Results.new(Quo::CollectionBackedQuery.wrap([]).new)
    refute results.exists?
    results = Quo::Results.new(Quo::CollectionBackedQuery.wrap([1]).new)
    assert results.exists?
  end

  test "#empty?" do
    results = Quo::Results.new(UnreadCommentsQuery.new)
    refute results.empty?
  end

  test "#group_by" do
    results = Quo::Results.new(UnreadCommentsQuery.new)
    grouped = results.group_by(&:post_id)
    assert_equal 2, grouped.keys.size
    assert_equal ["abc"], grouped[results.first.post_id].map(&:body)
  end

  test "#respond_to_missing?" do
    results = Quo::Results.new(UnreadCommentsQuery.new)
    assert results.respond_to?(:map)
    assert_not results.respond_to?(:non_existent_method)
  end
end
