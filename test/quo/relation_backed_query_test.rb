# frozen_string_literal: true

require_relative "../test_helper"

class Quo::RelationBackedQueryTest < ActiveSupport::TestCase
  def setup
    a1 = Author.create!(name: "John")
    a2 = Author.create!(name: "Jane")
    p1 = Post.create!(title: "Post 1", author: a1)
    p2 = Post.create!(title: "Post 2", author: a2)
    Comment.create!(post: p1, body: "abc", read: false)
    Comment.create!(post: p2, body: "def", read: false)
  end

  test "#copy makes a copy of this query object with different options" do
    q = NewCommentsForAuthorQuery.new(author_id: 1)
    q_copy = q.copy(author_id: 2)
    assert_instance_of NewCommentsForAuthorQuery, q_copy
    assert_not_equal q, q_copy
    assert_equal 2, q_copy.author_id
  end

  test "#with method for order" do
    q = UnreadCommentsQuery.new + Comment.joins(post: :author)
    comments = q.with(order: {"authors.name" => :asc})
    assert_equal "Jane", comments.results.first.post.author.name
  end

  test "#with method for limit" do
    assert_equal 1, UnreadCommentsQuery.new.with(limit: 1).results.count
  end

  test "#with method for group" do
    q = UnreadCommentsQuery.new + Comment.joins(post: :author)
    grouped = q.with(group: ["authors.id"]).results.count
    assert_equal 2, grouped.size
  end

  test "#with method for includes" do
    q = UnreadCommentsQuery.new
    comments = q.with(includes: [post: :author])
    assert_equal "John", comments.results.first.post.author.name
  end

  test "#with method for preload" do
    q = UnreadCommentsQuery.new
    comments = q.with(preload: [post: :author])
    assert_equal "John", comments.results.first.post.author.name
  end

  test "#with method for select" do
    q = UnreadCommentsQuery.new
    comments = q.with(select: ["id"])
    c = comments.results.first
    assert_raises(ActiveModel::MissingAttributeError) { c.body }
    refute_nil c.id
  end

  test "#to_a" do
    assert_instance_of Array, UnreadCommentsQuery.new.results.to_a
    assert_equal 2, UnreadCommentsQuery.new.results.to_a.size
  end

  test "#exists?/none?" do
    assert UnreadCommentsQuery.new.results.exists?
    refute UnreadCommentsQuery.new.results.none?
    assert NewCommentsForAuthorQuery.new(author_id: 1001).results.none?
  end

  test "#to_collection" do
    q = UnreadCommentsQuery.new
    eager = q.to_collection
    assert_kind_of Quo::CollectionBackedQuery, eager
    assert eager.collection?
    assert_equal 2, eager.results.count

    eager = q.to_collection(total_count: 100)
    assert_equal 100, eager.results.total_count
  end

  test "#relation?/collection?" do
    assert UnreadCommentsQuery.new.relation?
    assert UnreadCommentsQuery.new.to_collection.collection?
    refute UnreadCommentsQuery.new.collection?
    assert Quo::CollectionBackedQuery.wrap([]).new.collection?
    refute Quo::CollectionBackedQuery.wrap([]).new.relation?
  end

  test "#transform" do
    q = UnreadCommentsQuery.new.transform do |c|
      c.body = "hello #{c.body} world"
      c
    end
    results = q.results
    assert_equal "hello abc world", results.first.body
    assert_equal "hello def world", results.last.body
    assert_equal ["hello abc world", "hello def world"], results.first(2).map(&:body)
  end

  test "#tranform copies to new query" do
    q = UnreadCommentsQuery.new.transform do |c|
      c.body = "hello #{c.body} world"
      c
    end
    q = q.with(select: [:body])
    assert_equal "hello abc world", q.results.first.body
  end

  test "#transform?" do
    q = UnreadCommentsQuery.new.transform { |c| c }
    assert q.transform?
  end

  test "#to_sql" do
    q = NewCommentsForAuthorQuery.new(author_id: 1)
    assert_equal "SELECT \"comments\".* FROM \"comments\" INNER JOIN \"posts\" ON \"posts\".\"id\" = \"comments\".\"post_id\" INNER JOIN \"authors\" ON \"authors\".\"id\" = \"posts\".\"author_id\" WHERE \"comments\".\"read\" = 0 AND \"authors\".\"id\" = 1", q.to_sql

    q = NewCommentsForAuthorQuery.new(author_id: 1, page: 3, page_size: 12)
    assert q.to_sql.end_with?("\"authors\".\"id\" = 1 LIMIT 12 OFFSET 24")
  end

  test "#unwrap" do
    q = NewCommentsForAuthorQuery.new(author_id: 1)
    ar = q.unwrap
    assert_kind_of ActiveRecord::Relation, ar

    assert_instance_of Array, q.to_collection.unwrap
  end

  test "#each" do
    q = UnreadCommentsQuery.new
    a = []
    e = q.results.each { |c| a << c.body }
    assert_kind_of Array, e
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

  test "#next_page_query" do
    q = UnreadCommentsQuery.new(page: 1, page_size: 1)
    next_q = q.next_page_query
    assert_equal 2, next_q.page
    assert_equal 1, next_q.page_size
  end

  test "#previous_page_query" do
    q = UnreadCommentsQuery.new(page: 2, page_size: 1)
    prev_q = q.previous_page_query
    assert_equal 1, prev_q.page
    assert_equal 1, prev_q.page_size
  end

  test "it wraps an ActiveRecord relation" do
    query = Quo::RelationBackedQuery.wrap do
      Comment.not_spam
    end

    assert_equal Comment.not_spam.to_sql, query.new.to_sql
  end

  test "it wraps an ActiveRecord relation as argument" do
    query = Quo::RelationBackedQuery.wrap(Comment.not_spam)
    assert_equal Comment.not_spam.to_sql, query.new.to_sql
  end

  test "it wraps an ActiveRecord relation with props" do
    query = Quo::RelationBackedQuery.wrap(props: {spam_score: Literal::Types::ConstraintType.new(0...1.0)}) do
      Comment.not_spam(spam_score)
    end

    assert_equal Comment.not_spam.to_sql, query.new(spam_score: 0.5).to_sql
    assert query < Quo::RelationBackedQuery
  end

  test "it raises when wrapping something that is not a relation of Query instance" do
    assert_raises ArgumentError do
      Quo::RelationBackedQuery.wrap(CommentNotSpamQuery).new.unwrap # not an instance of Query
    end
  end

  test "it raises when wrapping something that is not a relation of Query instance with query from block" do
    assert_raises ArgumentError do
      Quo::RelationBackedQuery.wrap(props: {to_sql: Literal::Types::ConstraintType.new(0...1.0)}) do
        CommentNotSpamQuery # not an instance of Query
      end.new.unwrap
    end
  end

  test "it wraps a query object" do
    query = Quo::RelationBackedQuery.wrap(props: {threshold: Float}) do
      CommentNotSpamQuery.new(spam_score_threshold: threshold)
    end

    assert_equal CommentNotSpamQuery.new(spam_score_threshold: 0.9).to_sql, query.new(threshold: 0.9).to_sql
  end

  test "#with method for complex select with aggregate functions" do
    query = UnreadCommentsQuery.new
    modified_query = query.with(
      select: ["post_id", "COUNT(*) as comment_count"],
      group: ["post_id"]
    )

    assert_includes modified_query.to_sql, "COUNT(*) as comment_count"
    assert_includes modified_query.to_sql, "GROUP BY"
    assert_includes modified_query.to_sql, "post_id"
  end

  test "#with method for complex where conditions" do
    query = UnreadCommentsQuery.new
    modified_query = query.with(
      where: ["body LIKE ? OR post_id IN (?)", "%abc%", [1, 2]]
    )

    sql = modified_query.to_sql
    assert_includes sql, "body LIKE '%abc%'"
    assert_includes sql, "post_id IN (1, 2)"
  end

  test "#with method for complex joins with conditions" do
    # Create a more complex join query
    query = UnreadCommentsQuery.new
    modified_query = query.with(
      joins: {post: :author},
      where: {authors: {name: "John"}}
    )

    sql = modified_query.to_sql
    assert_includes sql, "INNER JOIN \"posts\" ON"
    assert_includes sql, "INNER JOIN \"authors\" ON"
    assert_includes sql, "\"authors\".\"name\" = 'John'"
  end

  test "#with method for ordering by multiple columns" do
    query = UnreadCommentsQuery.new
    modified_query = query.with(
      order: {post_id: :asc, id: :desc}
    )

    sql = modified_query.to_sql
    assert_includes sql, "ORDER BY"
    assert_includes sql, "\"comments\".\"post_id\" ASC"
    assert_includes sql, "\"comments\".\"id\" DESC"
  end

  test "#with method for eager loading with multiple levels" do
    query = UnreadCommentsQuery.new
    modified_query = query.with(
      includes: {post: :author}
    )

    includes_values = modified_query.unwrap.includes_values
    assert includes_values.present?

    if includes_values.first.is_a?(Hash)
      assert_includes includes_values.map(&:keys).flatten, :post
    else
      assert_includes includes_values, :post
    end
  end

  test "#with method for combining preload with where" do
    query = UnreadCommentsQuery.new
    post_with_comments = Post.first

    modified_query = query.with(
      preload: :post,
      where: {post_id: post_with_comments.id}
    )

    results = modified_query.results.to_a
    assert_not_empty results

    # Preloaded associations should be loaded without additional queries
    ActiveRecord::Base.connection.materialize_transactions
    query_count = 0
    counter = ->(*, started_at) { query_count += 1 }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      results.each do |comment|
        comment.post # This should not trigger a query if preloaded
      end
    end

    assert_equal 0, query_count, "Expected preloaded associations to not trigger additional queries"
  end

  test "#with method for distinct with select" do
    Comment.create!(post: Post.first, body: "duplicate", read: false)
    Comment.create!(post: Post.first, body: "duplicate", read: false)

    query = UnreadCommentsQuery.new
    modified_query = query.with(
      select: :body,
      distinct: true
    )

    assert_includes modified_query.to_sql, "SELECT DISTINCT"
  end

  test "#with method for offset and limit for pagination" do
    3.times { Comment.create!(post: Post.first, body: SecureRandom.hex(4), read: false) }

    query = UnreadCommentsQuery.new
    page_size = 2

    page1 = query.with(limit: page_size, offset: 0)
    page2 = query.with(limit: page_size, offset: page_size)

    assert_equal page_size, page1.results.count
    assert_not_equal page1.results.to_a, page2.results.to_a

    assert_includes page1.to_sql, "LIMIT #{page_size}"
    assert_includes page1.to_sql, "OFFSET 0"
    assert_includes page2.to_sql, "LIMIT #{page_size}"
    assert_includes page2.to_sql, "OFFSET #{page_size}"
  end

  test "#with method for complex query combining multiple options" do
    query = UnreadCommentsQuery.new

    complex_query = query.with(
      select: ["comments.id", "comments.body", "posts.title as post_title"],
      joins: :post,
      where: {posts: {id: Post.first.id}},
      order: {id: :desc},
      limit: 5
    )

    sql = complex_query.to_sql
    assert_includes sql, "SELECT"
    assert_includes sql, "INNER JOIN \"posts\""
    assert_includes sql, "WHERE"
    assert_includes sql, "\"posts\".\"id\" ="
    assert_includes sql, "ORDER BY \"comments\".\"id\" DESC"
    assert_includes sql, "LIMIT 5"

    results = complex_query.results.to_a
    assert_not_empty results
  end

  test "#with method for unscope" do
    query = UnreadCommentsQuery.new
    query_with_filter = query.with(where: {body: "test"})
    unscoped_query = query_with_filter.with(unscope: :where)

    assert_not_equal query_with_filter.to_sql, unscoped_query.to_sql
    assert_includes query_with_filter.to_sql, "WHERE"
    assert_includes query_with_filter.to_sql, "body"
    assert_includes query_with_filter.to_sql, "test"
    assert_not_includes unscoped_query.to_sql, "WHERE"
  end

  test "#with method for reorder" do
    query = UnreadCommentsQuery.new
    ordered_query = query.with(order: {id: :asc})
    reordered_query = ordered_query.with(reorder: {id: :desc})

    # Original order should be ASC, reordered should be DESC
    assert_includes ordered_query.to_sql, "\"comments\".\"id\" ASC"
    assert_includes reordered_query.to_sql, "\"comments\".\"id\" DESC"
  end

  test "#with_specification using immutable specifications" do
    query = UnreadCommentsQuery.new

    spec1 = Quo::QuerySpecification.new(limit: 2)
    spec2 = spec1.merge(order: {id: :desc})

    query1 = query.with_specification(spec1)
    query2 = query.with_specification(spec2)

    assert_includes query1.to_sql, "LIMIT 2"
    assert_not_includes query1.to_sql, "ORDER BY"

    assert_includes query2.to_sql, "LIMIT 2"
    assert_includes query2.to_sql, "ORDER BY \"comments\".\"id\" DESC"

    assert_equal({limit: 2}, spec1.options)
    assert_equal({limit: 2, order: {id: :desc}}, spec2.options)
  end

  test "chaining multiple with calls" do
    query = UnreadCommentsQuery.new

    result = query
      .with(select: ["id", "body"])
      .with(where: {body: "abc"})
      .with(order: {id: :desc})
      .with(limit: 1)

    sql = result.to_sql
    assert_includes sql, "SELECT \"comments\".\"id\", \"comments\".\"body\""
    assert_includes sql, "WHERE"
    assert_includes sql, "\"comments\".\"body\" = 'abc'"
    assert_includes sql, "ORDER BY \"comments\".\"id\" DESC"
    assert_includes sql, "LIMIT 1"
  end
end
