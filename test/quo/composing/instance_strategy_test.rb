# frozen_string_literal: true

require "test_helper"

class Quo::Composing::InstanceStrategyTest < ActiveSupport::TestCase
  def setup
    @strategy = Quo::Composing::InstanceStrategy.new
  end

  test "#validate_instances accepts valid instances" do
    left = Quo::RelationBackedQuery.wrap(Comment.all).new
    right = Quo::RelationBackedQuery.wrap(Comment.all).new
    result = @strategy.validate_instances(left, right)
    assert_nil result
  end

  test "#validate_instances raises when left is invalid" do
    left = Object.new
    right = Quo::RelationBackedQuery.wrap(Comment.all).new

    error = assert_raises(ArgumentError) do
      @strategy.validate_instances(left, right)
    end

    assert_match(/Cannot merge, left has incompatible type/, error.message)
  end

  test "#validate_instances raises when right is invalid" do
    left = Quo::RelationBackedQuery.wrap(Comment.all).new
    right = Object.new

    error = assert_raises(ArgumentError) do
      @strategy.validate_instances(left, right)
    end

    assert_match(/Cannot merge, right has incompatible type/, error.message)
  end

  test "#determine_base_class_for_queries returns RelationBackedQuery for both relation backed queries" do
    relation_class = Class.new(Quo::RelationBackedQuery)
    collection_class = Class.new(Quo::CollectionBackedQuery)

    Quo.stub :relation_backed_query_base_class, relation_class do
      Quo.stub :collection_backed_query_base_class, collection_class do
        left = Quo::RelationBackedQuery.wrap(Comment.all).new
        right = Quo::RelationBackedQuery.wrap(Comment.all).new

        base_class = @strategy.determine_base_class_for_queries(left, right)
        assert_equal relation_class, base_class
      end
    end
  end

  test "#determine_base_class_for_queries returns CollectionBackedQuery for mixed queries" do
    relation_class = Class.new(Quo::RelationBackedQuery)
    collection_class = Class.new(Quo::CollectionBackedQuery)

    Quo.stub :relation_backed_query_base_class, relation_class do
      Quo.stub :collection_backed_query_base_class, collection_class do
        left = Quo::RelationBackedQuery.wrap(Comment.all).new
        right = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new

        base_class = @strategy.determine_base_class_for_queries(left, right)
        assert_equal collection_class, base_class
      end
    end
  end
end
