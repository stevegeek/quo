# frozen_string_literal: true

require_relative "../test_helper"

class Quo::CollectionBackedQueryTest < ActiveSupport::TestCase
  test "creates a new loaded query object from an array" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    assert_kind_of Quo::CollectionBackedQuery, q
    assert_equal [1, 2, 3], q.to_a
    assert_equal 3, q.results.size
  end

  def create_query_class
    Class.new(Quo::CollectionBackedQuery) do
      prop :foo, Integer

      def collection
        [1, 2, 3]
      end
    end
  end

  test "#copy makes a copy of an query object with different options" do
    klass = create_query_class
    q = klass.new(foo: 1)
    q_copy = q.copy(foo: 2)
    assert_kind_of Quo::CollectionBackedQuery, q_copy
    assert_not_equal q, q_copy
    assert_equal 2, q_copy.foo
  end


  test "#count returns the size of the collection" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    assert_equal 3, q.count
  end

  test "#total_count returns the size of the collection" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    assert_equal 3, q.total_count
  end

  test "#size returns the size of the collection" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    assert_equal 3, q.size
  end

  test "#page_count returns the size of the collection" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    assert_equal 3, q.page_count
  end

  test "#paged? returns false when total_count is nil and page_index is not present" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    assert_not q.paged?
  end

  test "#relation? returns false" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    assert_not q.relation?
  end

  test "#select" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    assert_raises { q.select { |x| x > 1 } }
  end

  test "#order" do
    q = Quo::CollectionBackedQuery.wrap([3, 1, 2]).new
    assert_raises { q.order(:itself) }
  end

  test "#limit" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    assert_raises { q.limit(2) }
  end

  test "#group" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3, 1, 2, 3]).new
    assert_raises { q.group(&:itself) }
  end

  test "#includes" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    included = q.includes(:itself)
    assert_equal [1, 2, 3], included.to_a
  end

  test "#preload" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    preloaded = q.preload(:itself)
    assert_equal [1, 2, 3], preloaded.to_a
  end

  test "#first" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    assert_equal 1, q.first
    assert_equal [1, 2], q.first(2)
  end

  test "#last" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    assert_equal 3, q.last
    assert_equal [2, 3], q.last(2)
  end

  test "#to_a" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    assert_equal [1, 2, 3], q.to_a
  end

  test "#exists?" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    assert q.results.exists?
    q = Quo::CollectionBackedQuery.wrap([]).new
    refute q.results.exists?
  end

  test "#empty?" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    refute q.results.empty?
    q = Quo::CollectionBackedQuery.wrap([]).new
    assert q.results.empty?
  end

  test "#transform" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new.transform { |x| x * 2 }
    assert_equal [2, 4, 6], q.to_a
  end

  test "#transform?" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new.transform { |x| x }
    assert q.transform?
  end

  test "#to_sql" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    assert_nil q.to_sql
  end

  test "#unwrap" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    assert_equal [1, 2, 3], q.unwrap
  end

  test "#each" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    a = []
    q.results.each { |x| a << x }
    assert_equal [1, 2, 3], a
  end

  test "#map" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    mapped = q.results.map { |x| x * 2 }
    assert_equal [2, 4, 6], mapped
  end

  test "#distinct" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3, 1, 2, 3]).new
    distinct = q.distinct
    assert_equal [1, 2, 3], distinct.results.to_a
  end
end
