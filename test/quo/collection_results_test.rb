# frozen_string_literal: true

require "test_helper"

class Quo::CollectionResultsTest < ActiveSupport::TestCase
  setup do
    @collection = Quo::CollectionBackedQuery.wrap([1, 2, 3, 4]).new
    @results = Quo::CollectionResults.new(@collection)

    @transformer = ->(v, i) { v + 100 + i }
  end

  test "#each" do
    a = []
    @results.each { |c| a << c.to_s }
    assert_equal ["1", "2", "3", "4"], a
  end

  test "#map" do
    mapped = @results.map.with_index do |c, i|
      "hello #{c} #{i} world"
    end
    assert_equal ["hello 1 0 world", "hello 2 1 world", "hello 3 2 world", "hello 4 3 world"], mapped

    mapped = Quo::CollectionResults.new(@collection, transformer: @transformer).to_a
    assert_equal [101, 103, 105, 107], mapped
  end

  test "#take(2)" do
    assert_equal [1, 2], @results.take(2)

    taken = Quo::CollectionResults.new(@collection, transformer: @transformer).take(2)
    assert_equal [101, 103], taken
  end

  test "#exists?" do
    results = Quo::CollectionResults.new(Quo::CollectionBackedQuery.wrap([]).new)
    refute results.exists?
    results = Quo::CollectionResults.new(Quo::CollectionBackedQuery.wrap([1]).new)
    assert results.exists?
  end

  test "#empty?" do
    results = Quo::CollectionResults.new(Quo::CollectionBackedQuery.wrap([]).new)
    assert results.empty?
    results = Quo::CollectionResults.new(Quo::CollectionBackedQuery.wrap([1]).new)
    refute results.empty?
  end

  test "#group_by" do
    grouped = @results.group_by { |v| v % 2 }
    assert_equal 2, grouped.keys.size
    assert_equal [1, 3], grouped[1]
    assert_equal [2, 4], grouped[0]
  end

  test "#respond_to_missing?" do
    assert @results.respond_to?(:map)
    assert_not @results.respond_to?(:non_existent_method)
  end

  test "#first" do
    results = @results
    assert_equal 1, results.first
    assert_equal [1, 2], results.first(2)

    results = @collection.copy(page: 1, page_size: 1).results
    assert_equal 1, results.first
    results = @collection.copy(page: 2, page_size: 1).results
    assert_equal 2, results.first
    results = @collection.copy(page: 3, page_size: 2).results
    assert_nil results.first

    mapped = Quo::CollectionResults.new(@collection, transformer: @transformer).first(2)
    assert_equal [101, 103], mapped
  end
  #
  # test "#first!" do
  #   results = @results
  #   assert_equal "abc", results.first!.body
  #   assert_raises(ActiveRecord::RecordNotFound) { NewCommentsForAuthorQuery.new(author_id: 1001).results.first! }
  #
  #   results = q.copy(page: 1, page_size: 1).results
  #   assert_equal "abc", results.first.body
  #   results = q.copy(page: 2, page_size: 1).results
  #   assert_equal "def", results.first.body
  #   results = q.copy(page: 3, page_size: 1).results
  #   assert_raises(ActiveRecord::RecordNotFound) { results.first! }
  # end

  test "#last" do
    assert_equal 4, @results.last
    assert_equal [3, 4], @results.last(2)

    mapped = Quo::CollectionResults.new(@collection, transformer: @transformer).last(2)
    # Note that the transformer is applied to the output of an operation, so the indexes passed to transformer are not the indexes of the original collection
    # but the indexes of the result of the operation. Thats why this is not [105, 107] but [103, 105]
    assert_equal [103, 105], mapped
  end

  test "#paged?" do
    assert @collection.copy(page: 1, page_size: 1).paged?
    refute @collection.paged?
  end

  test "#page_count" do
    assert_equal 4, @collection.copy(page_size: 2).results.page_count
    assert_equal 2, @collection.copy(page: 1, page_size: 2).results.page_count
    assert_equal 0, @collection.copy(page: 3, page_size: 2).results.page_count
  end

  test "#total_count/count" do
    assert_equal 4, @results.total_count
    assert_equal 4, @collection.copy(page: 1, page_size: 1).results.total_count
    assert_equal 4, @results.count
    assert_equal 4, @collection.copy(page: 1, page_size: 1).results.count
  end

  # Regression coverage for issue #7: filter-style Enumerable methods previously
  # returned untransformed items while passing transformed items to the block.
  class Box
    attr_reader :value
    def initialize(value) = @value = value
    def even? = @value.even?
  end

  def boxed_results
    Quo::CollectionResults.new(@collection, transformer: ->(v, _i = nil) { Box.new(v) })
  end

  test "#select returns transformed items and yields transformed items" do
    seen = []
    filtered = boxed_results.select { |b|
      seen << b
      b.value > 2
    }
    assert(seen.all? { |b| b.is_a?(Box) })
    assert(filtered.all? { |b| b.is_a?(Box) })
    assert_equal [3, 4], filtered.map(&:value)
  end

  test "#reject returns transformed items and yields transformed items" do
    filtered = boxed_results.reject { |b| b.value > 2 }
    assert(filtered.all? { |b| b.is_a?(Box) })
    assert_equal [1, 2], filtered.map(&:value)
  end

  test "#find returns a transformed item" do
    found = boxed_results.find { |b| b.value == 3 }
    assert_instance_of Box, found
    assert_equal 3, found.value
  end

  test "#sort_by returns transformed items" do
    sorted = boxed_results.sort_by { |b| -b.value }
    assert(sorted.all? { |b| b.is_a?(Box) })
    assert_equal [4, 3, 2, 1], sorted.map(&:value)
  end

  test "#partition returns transformed items in both buckets" do
    evens, odds = boxed_results.partition { |b| b.even? }
    assert(evens.all? { |b| b.is_a?(Box) })
    assert(odds.all? { |b| b.is_a?(Box) })
    assert_equal [2, 4], evens.map(&:value)
    assert_equal [1, 3], odds.map(&:value)
  end

  test "#each_with_object yields transformed items, accumulator passes through" do
    sum = boxed_results.each_with_object([0]) { |b, memo| memo[0] += b.value }
    assert_equal [10], sum
  end

  test "#to_a returns transformed items" do
    arr = boxed_results.to_a
    assert(arr.all? { |b| b.is_a?(Box) })
    assert_equal [1, 2, 3, 4], arr.map(&:value)
  end

  test "#first returns a transformed item" do
    assert_instance_of Box, boxed_results.first
    firsts = boxed_results.first(2)
    assert(firsts.all? { |b| b.is_a?(Box) })
  end

  test "#last returns a transformed item" do
    assert_instance_of Box, boxed_results.last
    lasts = boxed_results.last(2)
    assert(lasts.all? { |b| b.is_a?(Box) })
  end

  test "#map yields transformed items and block return is used verbatim" do
    values = boxed_results.map { |b| b.value * 10 }
    assert_equal [10, 20, 30, 40], values
  end

  test "#count and #any? operate on the underlying data (not transformed)" do
    assert_equal 4, boxed_results.count
    assert boxed_results.any?
    refute boxed_results.empty?
    assert boxed_results.exists?
  end
end
