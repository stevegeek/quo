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

  test "#order" do
    q = UnreadCommentsQuery.new + Comment.joins(post: :author)
    comments = q.order("authors.name" => :asc)
    assert_equal "Jane", comments.results.first.post.author.name
  end

  test "#limit" do
    assert_equal 1, UnreadCommentsQuery.new.limit(1).results.count
  end

  test "#group" do
    q = UnreadCommentsQuery.new + Comment.joins(post: :author)
    grouped = q.group("authors.id").results.count
    assert_equal 2, grouped.size
  end

  test "#includes" do
    q = UnreadCommentsQuery.new
    comments = q.includes(post: :author)
    assert_equal "John", comments.results.first.post.author.name
  end

  test "#preload" do
    q = UnreadCommentsQuery.new
    comments = q.preload(post: :author)
    assert_equal "John", comments.results.first.post.author.name
  end

  test "#select" do
    q = UnreadCommentsQuery.new
    comments = q.select("id")
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
    q = q.select(:body)
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
    query = Quo::RelationBackedQuery.wrap(props: {spam_score: Literal::Types::FloatType.new(0...1.0)}) do
      Comment.not_spam(spam_score)
    end

    assert_equal Comment.not_spam.to_sql, query.new(spam_score: 0.5).to_sql
    assert query < Quo::RelationBackedQuery
  end

  test "it raises when wrapping an ActiveRecord relation with prop that shadows a method" do
    assert_raises ArgumentError do
      Quo::RelationBackedQuery.wrap(props: {to_sql: Literal::Types::FloatType.new(0...1.0)}) do
        Comment.not_spam
      end
    end
  end

  test "it wraps a query object" do
    query = Quo::RelationBackedQuery.wrap(props: {threshold: Float}) do
      CommentNotSpamQuery.new(spam_score_threshold: threshold)
    end

    assert_equal CommentNotSpamQuery.new(spam_score_threshold: 0.9).to_sql, query.new(threshold: 0.9).to_sql
  end
end
