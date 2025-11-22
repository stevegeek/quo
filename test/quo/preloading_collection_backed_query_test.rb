# frozen_string_literal: true

require "test_helper"

class Quo::ReloadableCollectionBackedQueryTest < ActiveSupport::TestCase
  def create_query_class
    Class.new(Quo::CollectionBackedQuery) do
      include Quo::Preloadable

      def collection
        [1, 2, 3]
      end
    end
  end

  test "#includes" do
    author = Author.create!(name: "John")
    q = create_query_class.wrap([author]).new
    q = q.includes(:posts)
    assert q.results.first.posts.loaded?
  end

  test "#preload" do
    author = Author.create!(name: "John")
    q = create_query_class.wrap([author]).new
    q = q.preload(:posts)
    assert q.results.first.posts.loaded?
  end

  test "#includes with multiple associations" do
    author = Author.create!(name: "John")
    post1 = Post.create!(title: "Post 1", author: author)
    post2 = Post.create!(title: "Post 2", author: author)
    Comment.create!(post: post1, body: "Comment 1")
    Comment.create!(post: post2, body: "Comment 2")

    q = create_query_class.wrap([post1, post2]).new
    q = q.includes(:author, :comments)

    results = q.results.to_a
    assert results.first.association(:author).loaded?
    assert results.first.association(:comments).loaded?
    assert results.last.association(:author).loaded?
    assert results.last.association(:comments).loaded?
  end

  test "#preload with multiple associations" do
    author = Author.create!(name: "Jane")
    post1 = Post.create!(title: "Post A", author: author)
    post2 = Post.create!(title: "Post B", author: author)
    Comment.create!(post: post1, body: "Comment A")
    Comment.create!(post: post2, body: "Comment B")

    q = create_query_class.wrap([post1, post2]).new
    q = q.preload(:author, :comments)

    results = q.results.to_a
    assert results.first.association(:author).loaded?
    assert results.first.association(:comments).loaded?
    assert results.last.association(:author).loaded?
    assert results.last.association(:comments).loaded?
  end
end
