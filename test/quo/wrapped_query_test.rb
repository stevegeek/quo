# frozen_string_literal: true

require "test_helper"

# Tests for the value-form wrappers introduced in 2.x:
#   Quo::RelationBackedQuery.from(relation)  -> Quo::WrappedRelationBackedQuery
#   Quo::CollectionBackedQuery.from(enum)    -> Quo::WrappedCollectionBackedQuery
#
# These wrap an existing relation/enumerable as a Quo::Query instance, with
# no per-call Class.new allocation.
class Quo::WrappedQueryTest < ActiveSupport::TestCase
  def setup
    @author = Author.create!(name: "Ada")
    @post = Post.create!(title: "Hi", author: @author)
    @c1 = Comment.create!(post: @post, body: "first", read: false)
    @c2 = Comment.create!(post: @post, body: "second", read: true)
  end

  # ---- RelationBackedQuery.from -----------------------------------------

  test ".from returns a value-form WrappedRelationBackedQuery, not a class" do
    q = Quo::RelationBackedQuery.from(Comment.all)

    assert_kind_of Quo::WrappedRelationBackedQuery, q
    assert_kind_of Quo::RelationBackedQuery, q
    assert_kind_of Quo::Query, q
    refute_kind_of Class, q
  end

  test ".from preserves the wrapped relation as the underlying query" do
    rel = Comment.where(read: false)
    q = Quo::RelationBackedQuery.from(rel)

    assert_equal rel.to_sql, q.unwrap_unpaginated.to_sql
  end

  test ".from results matches the wrapped relation" do
    q = Quo::RelationBackedQuery.from(Comment.where(read: false))

    assert_includes q.results, @c1
    refute_includes q.results, @c2
  end

  test ".from interoperates with v2 instance composition" do
    left = Quo::RelationBackedQuery.from(Comment.all)
    right = ::UnreadCommentsQuery.new

    composed = left + right
    assert_kind_of Quo::ComposedRelationBackedQuery, composed
    assert_includes composed.results, @c1
    refute_includes composed.results, @c2
  end

  test ".from supports the fluent API (.order, .where, .joins)" do
    q = Quo::RelationBackedQuery.from(Comment.all)
      .order(:body)
      .where(read: false)

    assert_includes q.to_sql, %(WHERE "comments"."read" = #{sql_false})
    assert_match(/ORDER BY "comments"\."body" ASC/, q.to_sql)
  end

  test ".from supports pagination" do
    20.times { |i| Comment.create!(post: @post, body: "extra-#{i}") }

    q = Quo::RelationBackedQuery.from(Comment.all).copy(page: 1, page_size: 10)
    assert q.paged?
    assert_equal 10, q.results.page_count
    assert_equal 22, q.results.count
  end

  test ".from allocates zero new classes per call (perf-critical)" do
    # The whole point of .from vs .wrap.new: no Class.new in the hot path.
    # Warm any one-time autoloads first so we measure steady-state cost.
    Quo::RelationBackedQuery.from(Comment.all)

    before = ObjectSpace.count_objects[:T_CLASS]
    100.times { Quo::RelationBackedQuery.from(Comment.all) }
    after = ObjectSpace.count_objects[:T_CLASS]

    assert_equal 0, after - before, "expected zero T_CLASS allocations from 100 .from calls"
  end

  # ---- CollectionBackedQuery.from ---------------------------------------

  test "CollectionBackedQuery.from returns a value-form Wrapped instance" do
    q = Quo::CollectionBackedQuery.from([1, 2, 3])

    assert_kind_of Quo::WrappedCollectionBackedQuery, q
    assert_kind_of Quo::CollectionBackedQuery, q
    assert_kind_of Quo::Query, q
    refute_kind_of Class, q
  end

  test "CollectionBackedQuery.from preserves the wrapped enumerable" do
    q = Quo::CollectionBackedQuery.from([10, 20, 30])

    assert_equal [10, 20, 30], q.unwrap_unpaginated.to_a
    assert_equal 3, q.results.count
  end

  test "CollectionBackedQuery.from interoperates with v2 instance composition" do
    left = Quo::CollectionBackedQuery.from([1, 2, 3])
    right = Quo::CollectionBackedQuery.from([4, 5, 6])

    composed = left + right
    assert_kind_of Quo::ComposedCollectionBackedQuery, composed
    assert_equal [1, 2, 3, 4, 5, 6], composed.results.to_a
  end

  test "CollectionBackedQuery.from allocates zero new classes per call" do
    # Warm any one-time autoloads first.
    Quo::CollectionBackedQuery.from([1, 2, 3])

    before = ObjectSpace.count_objects[:T_CLASS]
    100.times { Quo::CollectionBackedQuery.from([1, 2, 3]) }
    after = ObjectSpace.count_objects[:T_CLASS]

    assert_equal 0, after - before, "expected zero T_CLASS allocations from 100 .from calls"
  end

  # ---- Inheritance from configured base class --------------------------

  test ".from inherits from the configured RelationBackedQuery base class" do
    q = Quo::RelationBackedQuery.from(Comment.all)

    # ApplicationRelationQuery (the dummy app's configured base class)
    # defines #hello returning "relation". A value-form .from query must
    # inherit it, just as `wrap(...).new` does.
    assert_equal "relation", q.hello
    assert_kind_of ApplicationRelationQuery, q
  end

  test "CollectionBackedQuery.from inherits from the configured base class" do
    q = Quo::CollectionBackedQuery.from([1, 2, 3])

    # ApplicationCollectionQuery defines #hello returning "collection".
    assert_equal "collection", q.hello
    assert_kind_of ApplicationCollectionQuery, q
  end

  test "instance composition produces a value that inherits from the configured base class" do
    composed = Quo::RelationBackedQuery.from(Comment.all) + ::UnreadCommentsQuery.new

    assert_equal "relation", composed.hello
    assert_kind_of ApplicationRelationQuery, composed
  end

  test "collection instance composition inherits from the configured collection base class" do
    composed = Quo::CollectionBackedQuery.from([1, 2, 3]) + Quo::CollectionBackedQuery.from([4, 5, 6])

    assert_equal "collection", composed.hello
    assert_kind_of ApplicationCollectionQuery, composed
  end

  # ---- Compared to .wrap(rel).new --------------------------------------

  test ".wrap(rel).new still allocates a new class per call (existing behaviour)" do
    # Sanity-check the perf contrast: this is the pattern .from replaces.
    before = ObjectSpace.count_objects[:T_CLASS]
    100.times { Quo::RelationBackedQuery.wrap(Comment.all).new }
    after = ObjectSpace.count_objects[:T_CLASS]

    # Each wrap allocates a class. Exact count is implementation-dependent
    # (sometimes the GC collects mid-loop), but it should be substantially
    # more than zero.
    assert_operator after - before, :>, 0,
      "expected wrap(rel).new to allocate classes; got #{after - before}"
  end
end
