# frozen_string_literal: true

require "test_helper"

class FluentApiTest < ActiveSupport::TestCase
  class PostQuery < Quo::RelationBackedQuery
    def query
      Post.all
    end
  end

  test "supports fluent API for query methods" do
    # Create a query with fluent method chaining
    query = PostQuery.new.where(title: "Hello").order(:created_at).limit(10)

    # Verify that the SQL includes the appropriate clauses
    sql = query.to_sql
    assert_match(/WHERE "posts"."title" = 'Hello'/, sql)
    assert_match(/ORDER BY "posts"."created_at"/, sql)
    assert_match(/LIMIT 10/, sql)
  end

  test "allows combining fluent API with with() method" do
    # Create a query using both styles
    query = PostQuery.new
      .where(title: "Hello")
      .with(order: :created_at)
      .limit(10)

    # Verify that the SQL includes the appropriate clauses
    sql = query.to_sql
    assert_match(/WHERE "posts"."title" = 'Hello'/, sql)
    assert_match(/ORDER BY "posts"."created_at"/, sql)
    assert_match(/LIMIT 10/, sql)
  end

  test "each method call returns a new query instance" do
    original = PostQuery.new
    with_where = original.where(title: "Hello")
    with_order = with_where.order(:created_at)

    # Each should be a different instance
    refute_equal original.object_id, with_where.object_id
    refute_equal with_where.object_id, with_order.object_id

    # Original query should not be modified
    refute_match(/WHERE/, original.to_sql)
  end

  test "handles undefined methods appropriately" do
    assert_raises(NoMethodError) do
      PostQuery.new.non_existent_method
    end
  end
end
