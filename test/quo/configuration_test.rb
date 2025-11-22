# frozen_string_literal: true

require "test_helper"

class Quo::ConfigurationTest < ActiveSupport::TestCase
  def setup
    @original_default_page_size = Quo.default_page_size
    @original_max_page_size = Quo.max_page_size

    @author = Author.create!(name: "John")
    100.times do |i|
      Post.create!(title: "Post #{i}", author: @author)
    end
  end

  def teardown
    Quo.default_page_size = @original_default_page_size
    Quo.max_page_size = @original_max_page_size
  end

  test "default_page_size is used when page_size not specified" do
    Quo.default_page_size = 25

    query = AllPostsQuery.new(page: 1)

    assert_equal 25, query.results.page_count
    assert_equal 25, query.results.to_a.size
  end

  test "default page_size is 20 when not configured" do
    Quo.default_page_size = nil

    query = AllPostsQuery.new(page: 1)

    assert_equal 20, query.results.page_count
    assert_equal 20, query.results.to_a.size
  end

  test "max_page_size caps the page_size when exceeded" do
    Quo.max_page_size = 50

    # Request 200 items but should be capped at 50
    query = AllPostsQuery.new(page: 1, page_size: 200)

    assert_equal 50, query.results.page_count
    assert_equal 50, query.results.to_a.size
  end

  test "max_page_size allows page_size when under limit" do
    Quo.max_page_size = 100

    # Request 30 items which is under the 100 limit
    query = AllPostsQuery.new(page: 1, page_size: 30)

    assert_equal 30, query.results.page_count
    assert_equal 30, query.results.to_a.size
  end

  test "default max_page_size is 200 when not configured" do
    Quo.max_page_size = nil

    # Create more posts to test the cap
    200.times do |i|
      Post.create!(title: "Extra Post #{i}", author: @author)
    end

    # Request 500 items but should be capped at default 200
    query = AllPostsQuery.new(page: 1, page_size: 500)

    assert_equal 200, query.results.page_count  # Should be capped at 200
  end

  test "configuration works with CollectionBackedQuery" do
    Quo.default_page_size = 15
    Quo.max_page_size = 40

    items = (1..100).to_a
    query_class = Quo::CollectionBackedQuery.wrap(items)

    # Test default page size
    query1 = query_class.new(page: 1)
    assert_equal 15, query1.results.page_count

    # Test max page size enforcement
    query2 = query_class.new(page: 1, page_size: 100)
    assert_equal 40, query2.results.page_count
  end
end

# Test query class for configuration tests
class AllPostsQuery < Quo::RelationBackedQuery
  def query
    Post.order(created_at: :desc)
  end
end
