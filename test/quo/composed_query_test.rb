# frozen_string_literal: true

require_relative "../test_helper"

class Quo::ComposedQueryTest < ActiveSupport::TestCase
  def setup
    @a1 = Author.create!(name: "John")
    a2 = Author.create!(name: "Jane")
    p1 = Post.create!(title: "Post 1", author: @a1)
    p2 = Post.create!(title: "Post 2", author: a2)
    Comment.create!(post: p1, body: "abc", read: false)
    Comment.create!(post: p2, body: "def", read: false, spam_score: 0.8)
    Comment.create!(post: p1, body: "ghi", read: true, spam_score: 0.2)
    Comment.create!(post: p1, body: "jkl", read: false)

    @q1 = Quo::RelationBackedQuery.wrap(props: {since_date: Time}) do
      Comment.recent(since_date)
    end
    @q2 = Quo::RelationBackedQuery.wrap(props: {spam_score: Float}) do
      Comment.not_spam(spam_score)
    end

    @q_composed = Quo::RelationBackedQuery.wrap(::UnreadCommentsQuery.new).compose(::Comment.joins(post: :author))
  end

  test "merges two active record queries" do
    assert_equal 4, ::Comment.count
    klass = Quo::RelationBackedQuery.wrap(::Comment.recent).compose(::Comment.not_spam)
    assert_equal 3, klass.new.results.count
    assert_equal 2, klass.compose(::Comment.unread).new.results.count
  end

  test "merged result is a Quo Query and inherits from configured base class" do
    klass = Quo::RelationBackedQuery.wrap(::Comment.recent).compose(::Comment.not_spam)
    assert_equal ApplicationRelationQuery, klass.superclass
    assert_equal "relation", klass.new.hello
  end

  test "merges two Quo::Query objects" do
    klass = @q1.compose(@q2)
    q = klass.new(since_date: 1.day.ago, spam_score: 0.5, page_size: 50)
    assert_equal 3, q.results.count
    assert_equal 0.5, q.spam_score
    assert_equal 50, q.page_size
    assert_equal 4, klass.new(since_date: 1.day.ago, spam_score: 0.9).results.count
  end

  test "merges two instances of Quo::Query objects" do
    query = @q1.new(since_date: 1.day.ago).merge(@q2.new(spam_score: 0.5))
    assert_equal 3, query.results.count
  end

  test "merges two instances of Quo::Query objects with different values and takes rightmost" do
    klass = @q1.compose(@q2)
    q3 = klass.new(since_date: 1.day.ago, spam_score: 0.9)
    query = @q2.new(spam_score: 0.5).merge(q3)
    assert_equal 4, query.results.count
  end

  test "composes and generates valid SQL query" do
    left = NewCommentsForAuthorQuery.new(author_id: 1, page: 2, page_size: 25)
    right = CommentNotSpamQuery.new(spam_score_threshold: 0.5, page_size: 50) # Page size is 50 and page is 2 so offset is 50
    sql = "SELECT \"comments\".* FROM \"comments\" " \
      "INNER JOIN \"posts\" ON \"posts\".\"id\" = \"comments\".\"post_id\" " \
      "INNER JOIN \"authors\" ON \"authors\".\"id\" = \"posts\".\"author_id\" " \
      "WHERE \"comments\".\"read\" = 0 AND \"authors\".\"id\" = 1 AND (spam_score IS NULL OR spam_score < 0.5) LIMIT 50 OFFSET 50"
    composed = left.merge(right)
    assert_equal sql, composed.to_sql
  end

  test "composes collection queries" do
    left = Quo::CollectionBackedQuery.wrap([1, 2, 3])
    right = Quo::CollectionBackedQuery.wrap([4, 5, 6])
    composed = left + right
    assert_equal "collection", composed.new.hello
    assert_equal [1, 2, 3, 4, 5, 6], composed.new.results.to_a
  end

  test "composes query and collection queries" do
    composed = NewCommentsForAuthorQuery.compose(Quo::CollectionBackedQuery.wrap([4, 5, 6]))
    q = composed.new(author_id: @a1.id)
    assert_kind_of Quo::ComposedQuery, q
    assert_equal 1, q.author_id
    assert_equal "abc", q.results.first.body
    assert_equal 6, q.results.last
  end

  test "composes collection and relation backed queries" do
    composed = Quo::CollectionBackedQuery.wrap([4, 5, 6]).compose(NewCommentsForAuthorQuery)
    q = composed.new(author_id: @a1.id)
    assert_kind_of Quo::ComposedQuery, q
    assert_equal 1, q.author_id
    assert_equal 4, q.results.first
    assert_equal "jkl", q.results.last.body
  end

  test "composes query and collection queries, with pagination" do
    composed = NewCommentsForAuthorQuery.compose(Quo::CollectionBackedQuery.wrap([4, 5, 6]))
    q = composed.new(author_id: @a1.id, page: 1, page_size: 2)
    # Apply pagination taking into account the collection content.
    # Result set is ("abc", "jkl"), (4, 5), (6)
    assert_kind_of Quo::ComposedQuery, q
    assert_equal 1, q.author_id
    assert_equal "abc", q.results.first.body
    assert_equal "jkl", q.results.last.body

    q = q.next_page_query
    assert_equal 4, q.results.first
    assert_equal 5, q.results.last
  end

  test "composes collection and relation backed queries, with pagination" do
    composed = Quo::CollectionBackedQuery.wrap([4, 5, 6]).compose(NewCommentsForAuthorQuery)
    q = composed.new(author_id: @a1.id, page: 2, page_size: 2)
    # Apply pagination taking into account the collection content.
    # Result set is (4, 5), (6, "abc"), ("jkl")
    assert_kind_of Quo::ComposedQuery, q
    assert_equal 1, q.author_id
    assert_equal 6, q.results.first
    assert_equal "abc", q.results.last.body

    q = q.next_page_query
    assert_equal "jkl", q.results.first.body
  end

  test "raises when invalid objects are composed" do
    assert_raises(ArgumentError) do
      Quo::Composing.composer(Quo::CollectionBackedQuery, Object.new, Quo::CollectionBackedQuery.wrap([]))
    end
  end

  test "#inspect when 1 source is a query object subclass" do
    merged = CommentNotSpamQuery.compose(Quo::CollectionBackedQuery)
    assert_equal "ApplicationRelationQuery<Quo::ComposedQuery>[CommentNotSpamQuery, Quo::CollectionBackedQuery]", merged.inspect
  end

  test "#inspect when 2 collection sources are provided" do
    merged = Quo::CollectionBackedQuery.wrap([]).new.merge(Quo::CollectionBackedQuery.wrap([]).new)
    assert_kind_of Quo::ComposedQuery, merged
    assert_includes merged.inspect, "Quo::CollectionBackedQuery<Quo::ComposedQuery>[Quo::CollectionBackedQuery, Quo::CollectionBackedQuery]"
  end

  test "#inspect when 1 source is a merged query" do
    nested = CommentNotSpamQuery.compose(UnreadCommentsQuery)
    merged = nested.compose(Quo::CollectionBackedQuery)
    assert_equal "ApplicationRelationQuery<Quo::ComposedQuery>[ApplicationRelationQuery<Quo::ComposedQuery>[CommentNotSpamQuery, UnreadCommentsQuery], Quo::CollectionBackedQuery]", merged.inspect
  end

  test "#copy makes a copy of this query object with different options" do
    q = @q1.new(since_date: 1.day.ago).merge(@q2.new(spam_score: 0.5))
    q_copy = q.copy(spam_score: 0.9)
    assert_kind_of Quo::ComposedQuery, q_copy
    assert_not_equal q, q_copy
    assert_equal 0.9, q_copy.spam_score
  end

  test "#count" do
    assert_equal 3, @q_composed.new.results.count
  end

  test "#paged?" do
    assert ::UnreadCommentsQuery.new(page: 1, page_size: 1).merge(::Comment.joins(post: :author)).paged?
    refute @q_composed.new.paged?
  end

  test "#count with paging (count ignores paging)" do
    assert_equal 3, ::UnreadCommentsQuery.new(page_size: 1).merge(::Comment.joins(post: :author)).results.count
  end

  test "#page_count" do
    assert_equal 3, @q_composed.new.results.page_count
  end

  test "#page_count with paging" do
    assert_equal 1, ::UnreadCommentsQuery.new(page: 1, page_size: 1).merge(::Comment.joins(post: :author)).results.page_count
  end

  test "#count with selects" do
    assert_equal 3, Quo::RelationBackedQuery.wrap(Comment.where(read: false).joins(:post).select(:id, "posts.id")).new.merge(
      ::UnreadCommentsQuery.new
    ).results.count
  end

  test "#relation?/collection?" do
    assert @q_composed.new.relation?
    assert @q_composed.new.to_collection.collection?
    refute @q_composed.new.collection?
    assert Quo::CollectionBackedQuery.wrap([]).compose(::Comment.joins(post: :author)).new.collection?
    refute Quo::CollectionBackedQuery.wrap([]).compose(::Comment.joins(post: :author)).new.relation?
  end

  test "#first" do
    q = @q_composed.new
    results = q.results
    assert_equal "abc", results.first.body
    assert_equal ["abc", "def"], results.first(2).map(&:body)

    results = q.copy(page: 1, page_size: 1).results
    assert_equal "abc", results.first.body
    results = q.copy(page: 2, page_size: 1).results
    assert_equal "def", results.first.body
    results = q.copy(page: 3, page_size: 1).results
    assert_equal "jkl", results.first.body
    results = q.copy(page: 4, page_size: 1).results
    assert_nil results.first
  end

  test "#first!" do
    q = @q_composed.new
    results = q.results
    assert_equal "abc", results.first!.body
    assert_raises(ActiveRecord::RecordNotFound) { @q_composed.compose(::NewCommentsForAuthorQuery).new(author_id: 1001).results.first! }

    results = q.copy(page: 1, page_size: 1).results
    assert_equal "abc", results.first.body
    results = q.copy(page: 2, page_size: 1).results
    assert_equal "def", results.first.body
    results = q.copy(page: 3, page_size: 1).results
    assert_equal "jkl", results.first.body
    results = q.copy(page: 4, page_size: 1).results
    assert_raises(ActiveRecord::RecordNotFound) { results.first! }
  end

  test "#last" do
    q = @q_composed.new
    assert_equal "jkl", q.results.last.body
    assert_equal ["def", "jkl"], q.results.last(2).map(&:body)
  end

  test "#transform" do
    q = @q_composed.new.transform do |c|
      c.body = "hello #{c.body} world"
      c
    end
    results = q.results
    assert_equal "hello abc world", results.first.body
    assert_equal "hello jkl world", results.last.body
    assert_equal ["hello abc world", "hello def world"], results.first(2).map(&:body)
    assert_equal ["hello def world", "hello jkl world"], results.last(2).map(&:body)
  end

  test "#each" do
    q = @q_composed.new
    a = []
    e = q.results.each { |c| a << c.body }
    assert_kind_of Array, e
    assert_equal ["abc", "def", "jkl"], a
    assert_kind_of Comment, e.first
  end

  test "#map" do
    mapped = @q_composed.new.results.map.with_index do |c, i|
      c.body = "hello #{i}"
      c
    end
    assert_equal ["hello 0", "hello 1", "hello 2"], mapped.map(&:body)
  end

  test "merged query applies specifications when composing relation backed queries" do
    query_with_order = Quo::RelationBackedQuery.wrap(Comment.all).new.order(:created_at)
    query_with_joins = Quo::RelationBackedQuery.wrap(Comment.all).new.joins(post: :author)

    # Merge the queries
    merged_query = query_with_order.merge(query_with_joins)

    # Verify that the query gets executed properly with both specifications
    sql = merged_query.to_sql
    assert_match(/"comments"\."created_at" ASC/, sql)
    assert_match(/INNER JOIN "authors"/, sql)
  end
end
