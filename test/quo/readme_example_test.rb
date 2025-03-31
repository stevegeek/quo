# frozen_string_literal: true

require "test_helper"

class Quo::ReadmeExampleTest < ActiveSupport::TestCase
  class RecentPostsQuery < Quo::RelationBackedQuery
    prop :days_ago, Integer, default: -> { 7 }

    def query
      Post.where(Post.arel_table[:created_at].gt(days_ago.days.ago))
        .order(created_at: :desc)
    end
  end

  class CommentNotSpamQuery < Quo::RelationBackedQuery
    prop :spam_score_threshold, _Float(0..1.0)

    def query
      comments = Comment.arel_table
      Comment.where(
        comments[:spam_score].eq(nil).or(
          comments[:spam_score].lt(spam_score_threshold)
        )
      )
    end
  end

  class PostPresenter
    attr_reader :post

    def initialize(post)
      @post = post
    end

    def formatted_title
      "#{post.title} (by #{post.author.name})"
    end
  end

  def setup
    @author1 = Author.create!(name: "John")
    @author2 = Author.create!(name: "Jane")

    # Create posts with varying creation dates
    @recent_post = Post.create!(
      title: "Recent Post",
      author: @author1,
      created_at: 2.days.ago
    )

    @older_post = Post.create!(
      title: "Older Post",
      author: @author2,
      created_at: 14.days.ago
    )

    # Create comments with varying spam scores
    @comment1 = Comment.create!(
      post: @recent_post,
      body: "Good content",
      read: false,
      spam_score: 0.1
    )

    @comment2 = Comment.create!(
      post: @older_post,
      body: "Spam content",
      read: false,
      spam_score: 0.8
    )

    @comment3 = Comment.create!(
      post: @recent_post,
      body: "No spam score",
      read: true,
      spam_score: nil
    )
  end

  test "RecentPostsQuery returns posts created within days_ago" do
    query = RecentPostsQuery.new
    results = query.results

    assert_includes results, @recent_post
    assert_not_includes results, @older_post
    assert_equal 1, results.count
  end

  test "RecentPostsQuery with custom days_ago" do
    query = RecentPostsQuery.new(days_ago: 30)
    results = query.results

    assert_includes results, @recent_post
    assert_includes results, @older_post
    assert_equal 2, results.count
  end

  test "RecentPostsQuery with pagination" do
    5.times do |i|
      Post.create!(
        title: "Paginated Post #{i}",
        author: @author1,
        created_at: 1.day.ago
      )
    end

    posts_query = RecentPostsQuery.new(days_ago: 30, page: 1, page_size: 2)
    page1 = posts_query.results

    assert_equal 2, page1.to_a.size
    assert_equal 7, page1.total_count  # 7 total posts (2 from setup + 5 created here)

    page2_query = posts_query.next_page_query
    page2 = page2_query.results

    assert_equal 2, page2.to_a.size
    assert_equal 2, page2_query.page
  end

  test "CommentNotSpamQuery filters out spam comments" do
    query = CommentNotSpamQuery.new(spam_score_threshold: 0.5)
    results = query.results

    assert_includes results, @comment1
    assert_not_includes results, @comment2
    assert_includes results, @comment3
    assert_equal 2, results.count
  end

  test "Composed query example with correct join strategy" do
    recent_posts_query = RecentPostsQuery.new(days_ago: 10)
    non_spam_comments_query = CommentNotSpamQuery.new(spam_score_threshold: 0.5)
    composed_query = recent_posts_query.joins(:comments) + non_spam_comments_query
    results = composed_query.results
    assert_includes results, @recent_post
    assert_not_includes results, @older_post
  end

  test "Transform example" do
    posts_last_10_days = RecentPostsQuery.new(days_ago: 10)
    transformed_query = posts_last_10_days.transform { |post| PostPresenter.new(post) }
    results = transformed_query.results

    assert_equal 1, results.count
    assert_instance_of PostPresenter, results.first
    assert_equal "Recent Post (by John)", results.first.formatted_title
  end
end
