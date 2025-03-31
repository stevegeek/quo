# frozen_string_literal: true

require "test_helper"

class Quo::AdditionalCollectionBackedQueryTest < ActiveSupport::TestCase
  test "wrap with block creates a query class" do
    block_data = [4, 5, 6]
    klass = Quo::CollectionBackedQuery.wrap do
      block_data
    end

    query = klass.new
    assert_equal block_data, query.collection
  end

  test "wrap with properties creates props" do
    klass = Quo::CollectionBackedQuery.wrap([1, 2, 3], props: {
      filter_value: Integer
    })

    query = klass.new(filter_value: 10)
    assert_equal 10, query.filter_value
  end

  test "wrap with property objects" do
    property_class = Class.new(Literal::Struct) do
      prop :filter_value, Integer
    end
    property_instance = property_class.new(filter_value: 5)
    property = property_instance.class.literal_properties.properties_index[:filter_value]

    klass = Quo::CollectionBackedQuery.wrap([1, 2, 3], props: {
      filter_value: property
    })

    query = klass.new(filter_value: 10)
    assert_equal 10, query.filter_value
  end

  test "wrap raises ArgumentError without data or block" do
    error = assert_raises(ArgumentError) do
      Quo::CollectionBackedQuery.wrap
    end
    assert_equal "either a query or a block must be provided", error.message
  end

  test "collection raises NotImplementedError for base class" do
    error = assert_raises(NotImplementedError) do
      Quo::CollectionBackedQuery.new.collection
    end
    assert_equal "Collection backed query objects must define a 'collection' method", error.message
  end

  test "query delegates to collection by default" do
    klass = Quo::CollectionBackedQuery.wrap([1, 2, 3])
    query = klass.new
    assert_equal [1, 2, 3], query.query
  end

  test "configured_query handles array-like collections with paging" do
    data = [1, 2, 3, 4, 5]
    klass = Quo::CollectionBackedQuery.wrap(data)

    query = klass.new(page: 1, page_size: 2)
    configured_query = query.send(:configured_query)
    assert_equal [1, 2], configured_query
  end

  test "configured_query handles non-array collections" do
    # Set is enumerable but doesn't respond to []
    data = Set.new([1, 2, 3])
    klass = Quo::CollectionBackedQuery.wrap(data)

    query = klass.new(page: 1, page_size: 2)
    configured_query = query.send(:configured_query)
    # Should return the original set since it can't be paginated
    assert_equal data, configured_query
  end

  test "#results.total_count with explicit total_count" do
    data = [1, 2, 3]
    klass = Quo::CollectionBackedQuery.wrap(data)

    query = klass.new
    # Set an explicit total count that differs from the array size
    query.instance_variable_set(:@total_count, 10)

    # Results total count should use the explicit value
    assert_equal 10, query.results.total_count
  end

  test "#collection? returns true" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    assert q.collection?
  end

  test "#to_collection returns self" do
    q = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
    assert_equal q, q.to_collection
  end
end
