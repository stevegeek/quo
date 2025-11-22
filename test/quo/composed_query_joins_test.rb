# frozen_string_literal: true

require "test_helper"

class Quo::ComposedQueryJoinsTest < ActiveSupport::TestCase
  def setup
    # Create test data
    @author1 = Author.create!(name: "John")
    @author2 = Author.create!(name: "Jane")
    @post1 = Post.create!(title: "Post 1", author: @author1)
    @post2 = Post.create!(title: "Post with a really long title that exceeds thirty characters", author: @author2)
    @comment1 = Comment.create!(post: @post1, body: "Comment 1", read: false)
    @comment2 = Comment.create!(post: @post1, body: "Comment 2", read: true)
    @comment3 = Comment.create!(post: @post2, body: "Comment 3", read: false)
    @comment4 = Comment.create!(post: @post2, body: "Comment 4", read: true)
  end

  def assert_results(composed_query)
    # Verify the join is present in the SQL
    sql = composed_query.to_sql
    assert_includes sql, "INNER JOIN \"posts\" ON \"posts\".\"id\" = \"comments\".\"post_id\" WHERE"
    assert_includes sql, "LENGTH(\"posts\".\"title\") > 30"
    results = composed_query.results
    assert_includes results, @comment3
    assert_not_includes results, @comment1 # post title too short
    assert_not_includes results, @comment2 # post is read and title too short
    assert_not_includes results, @comment4 # post is read
    assert_equal 1, results.count
  end

  def post_relation
    posts = Post.arel_table
    length_function = Arel::Nodes::NamedFunction.new("LENGTH", [posts[:title]])
    Post.where(length_function.gt(30))
  end

  test "composes query classes with explicit joins argument at class level" do
    composed_class = UnreadCommentsQuery.compose(LongTitlePostQuery, joins: :post)
    composed_query = composed_class.new

    assert_results(composed_query)
    assert_instance_of Class, composed_class
    assert composed_class < Quo::RelationBackedQuery
  end

  test "composes comment query with post query using explicit joins argument" do
    comment_query = UnreadCommentsQuery.new
    post_query = LongTitlePostQuery.new

    # Compose with explicit joins argument
    composed_query = comment_query.merge(post_query, joins: :post)

    assert_results(composed_query)
  end

  test "composes query object with joins in left hand specification" do
    # Create comment query with specification that includes joins
    comment_query = UnreadCommentsQuery.new.joins(:post)
    post_query = LongTitlePostQuery.new

    # Merge the queries
    composed_query = comment_query.merge(post_query)

    assert_results(composed_query)
  end

  test "query object with joins in right hand specification is not support as per ActiveRecord" do
    # Create comment query with specification that includes joins
    comment_query = UnreadCommentsQuery.new
    post_query = LongTitlePostQuery.new.joins(:comments)

    # Merge the queries
    composed_query = comment_query.merge(post_query)

    assert_raises do
      composed_query.results.first
    end
  end

  test "composes comment query with explicit joins to post relation" do
    comment_query = UnreadCommentsQuery.new

    composed_query = comment_query.merge(post_relation, joins: :post)

    assert_results(composed_query)
  end

  test "composes comment query with joins in Specification" do
    comment_query = UnreadCommentsQuery.new.joins(:post)

    composed_query = comment_query.merge(post_relation)

    assert_results(composed_query)
  end

  test "composes relation with explicit joins and query" do
    comment_relation = Comment.unread
    post_query = LongTitlePostQuery.new

    composed_query = Quo::Composing.merge_instances(comment_relation, post_query, joins: :post)

    assert_results(composed_query)
  end

  test "composes relation with preconfigured joins and query" do
    comment_relation = Comment.unread.joins(:post)
    post_query = LongTitlePostQuery.new

    composed_query = Quo::Composing.merge_instances(comment_relation, post_query)

    assert_results(composed_query)
  end

  test "composes relations with explicit joins" do
    comment_relation = Comment.unread.joins(:post)

    composed_query = Quo::Composing.merge_instances(comment_relation, post_relation)

    assert_results(composed_query)
  end

  test "composes multiple queries with different join conditions between comments and posts" do
    # Create queries
    unread_query = UnreadCommentsQuery.new
    spam_query = CommentNotSpamQuery.new(spam_score_threshold: 0.5)
    post_query = LongTitlePostQuery.new(min_length: 30)

    # Compose all three queries
    composed_query = unread_query.merge(spam_query).merge(post_query, joins: :post)

    # Verify the SQL contains all joins and conditions
    sql = composed_query.to_sql
    assert_includes sql, "INNER JOIN \"posts\" ON \"posts\".\"id\" = \"comments\".\"post_id\" WHERE"
    assert_includes sql, "LENGTH(\"posts\".\"title\") > 30"
    assert_includes sql, "\"comments\".\"read\" = 0"
    assert_includes sql, "spam_score IS NULL OR spam_score < 0.5"
  end
end
