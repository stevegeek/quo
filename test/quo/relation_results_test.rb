# frozen_string_literal: true

require "test_helper"

class Quo::RelationResultsTest < ActiveSupport::TestCase
  def setup
    @a1 = Author.create!(name: "John")
    a2 = Author.create!(name: "Jane")
    p1 = Post.create!(title: "Post 1", author: @a1)
    p2 = Post.create!(title: "Post 2", author: a2)
    Comment.create!(post: p1, body: "abc", read: false)
    Comment.create!(post: p2, body: "def", read: false)
  end

  test "#each" do
    e = Quo::RelationResults.new(UnreadCommentsQuery.new)
    a = []
    e.each { |c| a << c.body }
    assert_kind_of Quo::RelationResults, e
    assert_equal ["abc", "def"], a
    assert_kind_of Comment, e.first
  end

  test "#map" do
    mapped = UnreadCommentsQuery.new.results.map.with_index do |c, i|
      c.body = "hello #{i} world"
      c
    end
    assert_equal ["hello 0 world", "hello 1 world"], mapped.map(&:body)
  end

  test "#take(2)" do
    taken = Quo::RelationResults.new(UnreadCommentsQuery.new).take(2)
    assert_equal ["abc", "def"], taken.map(&:body)

    t = ->(v, i) {
      v.body = i
      v
    }
    taken = Quo::RelationResults.new(UnreadCommentsQuery.new, transformer: t).take(2)
    assert_equal ["0", "1"], taken.map(&:body)
  end

  test "#exists?" do
    results = UnreadCommentsQuery.new.results
    assert results.exists?
    results = NewCommentsForAuthorQuery.new(author_id: 1001).results
    refute results.exists?
    results = NewCommentsForAuthorQuery.new(author_id: @a1.id).results
    assert results.exists?
  end

  test "#empty?" do
    results = UnreadCommentsQuery.new.results
    refute results.empty?
  end

  test "#group_by" do
    results = UnreadCommentsQuery.new.results
    grouped = results.group_by(&:post_id)
    assert_equal 2, grouped.keys.size
    assert_equal ["abc"], grouped[results.first.post_id].map(&:body)
  end

  test "#respond_to_missing?" do
    results = UnreadCommentsQuery.new.results
    assert results.respond_to?(:map)
    assert_not results.respond_to?(:non_existent_method)
  end

  test "#first" do
    q = UnreadCommentsQuery.new
    results = q.results
    assert_equal "abc", results.first.body
    assert_equal ["abc", "def"], results.first(2).map(&:body)

    results = q.copy(page: 1, page_size: 1).results
    assert_equal "abc", results.first.body
    results = q.copy(page: 2, page_size: 1).results
    assert_equal "def", results.first.body
    results = q.copy(page: 3, page_size: 1).results
    assert_nil results.first
  end

  test "#first!" do
    q = UnreadCommentsQuery.new
    results = q.results
    assert_equal "abc", results.first!.body
    assert_raises(ActiveRecord::RecordNotFound) { NewCommentsForAuthorQuery.new(author_id: 1001).results.first! }

    results = q.copy(page: 1, page_size: 1).results
    assert_equal "abc", results.first.body
    results = q.copy(page: 2, page_size: 1).results
    assert_equal "def", results.first.body
    results = q.copy(page: 3, page_size: 1).results
    assert_raises(ActiveRecord::RecordNotFound) { results.first! }
  end

  test "#last" do
    q = UnreadCommentsQuery.new
    assert_equal "def", q.results.last.body
    assert_equal ["abc", "def"], q.results.last(2).map(&:body)
  end

  test "#count" do
    assert_equal 2, UnreadCommentsQuery.new.results.count
  end

  test "#paged?" do
    assert UnreadCommentsQuery.new(page: 1, page_size: 1).paged?
    refute UnreadCommentsQuery.new.paged?
  end

  test "#count with paging" do
    assert_equal 2, UnreadCommentsQuery.new(page_size: 1).results.count
  end

  test "#count with selects" do
    assert_equal 2, Quo::RelationBackedQuery.wrap(Comment.where(read: false).joins(:post).select(:id, "posts.id")).new.results.count
  end

  test "#page_count" do
    assert_equal 2, UnreadCommentsQuery.new.results.page_count
  end

  test "#page_count with paging" do
    assert_equal 1, UnreadCommentsQuery.new(page: 1, page_size: 1).results.page_count
  end

  test "#total_count" do
    assert_equal 2, UnreadCommentsQuery.new.results.total_count
    assert_equal 2, UnreadCommentsQuery.new(page: 1, page_size: 1).results.total_count
  end

  test "raises if passed a collection backed query" do
    assert_raises(ArgumentError) { Quo::RelationResults.new(Quo::CollectionBackedQuery.wrap([]).new) }
  end

  # Regression coverage for issue #7: filter-style Enumerable methods used to
  # yield transformed items into the user block but return the underlying
  # (untransformed) items from @configured_query.
  class CommentPresenter
    attr_reader :comment
    def initialize(comment) = @comment = comment
    def body = @comment.body
    def upcased = @comment.body.upcase
  end

  def presented_query
    UnreadCommentsQuery.new.transform { |c| CommentPresenter.new(c) }
  end

  test "#select returns transformed items and yields transformed items" do
    seen = []
    filtered = presented_query.results.select { |p|
      seen << p
      p.body.start_with?("a")
    }
    assert(seen.all? { |p| p.is_a?(CommentPresenter) })
    assert_equal 1, filtered.size
    assert(filtered.all? { |p| p.is_a?(CommentPresenter) })
    assert_equal ["abc"], filtered.map(&:body)
  end

  test "#reject returns transformed items and yields transformed items" do
    seen = []
    filtered = presented_query.results.reject { |p|
      seen << p
      p.body.start_with?("a")
    }
    assert(seen.all? { |p| p.is_a?(CommentPresenter) })
    assert_equal 1, filtered.size
    assert(filtered.all? { |p| p.is_a?(CommentPresenter) })
    assert_equal ["def"], filtered.map(&:body)
  end

  test "#find returns a transformed item and yields transformed items" do
    seen = []
    found = presented_query.results.find { |p|
      seen << p
      p.body == "def"
    }
    assert(seen.all? { |p| p.is_a?(CommentPresenter) })
    assert_instance_of CommentPresenter, found
    assert_equal "def", found.body
  end

  test "#sort_by returns transformed items and yields transformed items" do
    seen = []
    sorted = presented_query.results.sort_by { |p|
      seen << p
      -p.body.ord
    }
    assert(seen.all? { |p| p.is_a?(CommentPresenter) })
    assert(sorted.all? { |p| p.is_a?(CommentPresenter) })
    assert_equal ["def", "abc"], sorted.map(&:body)
  end

  test "#partition returns transformed items in both buckets" do
    matches, others = presented_query.results.partition { |p| p.body == "abc" }
    assert(matches.all? { |p| p.is_a?(CommentPresenter) })
    assert(others.all? { |p| p.is_a?(CommentPresenter) })
    assert_equal ["abc"], matches.map(&:body)
    assert_equal ["def"], others.map(&:body)
  end

  test "#each_with_object yields transformed items, accumulator passes through" do
    acc = presented_query.results.each_with_object([]) { |p, memo| memo << p.upcased }
    assert_equal ["ABC", "DEF"], acc
  end

  test "#to_a returns transformed items" do
    arr = presented_query.results.to_a
    assert(arr.all? { |p| p.is_a?(CommentPresenter) })
    assert_equal ["abc", "def"], arr.map(&:body)
  end

  test "#first returns a transformed item" do
    assert_instance_of CommentPresenter, presented_query.results.first
    firsts = presented_query.results.first(2)
    assert(firsts.all? { |p| p.is_a?(CommentPresenter) })
  end

  test "#last returns a transformed item" do
    assert_instance_of CommentPresenter, presented_query.results.last
    lasts = presented_query.results.last(2)
    assert(lasts.all? { |p| p.is_a?(CommentPresenter) })
  end

  test "#map yields transformed items and block return is used verbatim" do
    bodies = presented_query.results.map { |p| p.body }
    assert_equal ["abc", "def"], bodies
  end

  test "#count, #any?, #empty? operate on the underlying data (not transformed)" do
    results = presented_query.results
    assert_equal 2, results.count
    assert results.any?
    refute results.empty?
    assert results.exists?
  end
end
