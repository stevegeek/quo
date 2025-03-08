# frozen_string_literal: true

require_relative "../test_helper"

module Quo
  module Test
    module TestExtension
      def custom_method
        "extended"
      end
    end
  end
end

class Quo::RelationBackedQuerySpecificationTest < ActiveSupport::TestCase
  setup do
    @spec = Quo::RelationBackedQuerySpecification.new
    @relation = Comment.all
  end

  test "initialize with empty options" do
    spec = Quo::RelationBackedQuerySpecification.new
    assert_empty spec.options
  end

  test "initialize with options" do
    spec = Quo::RelationBackedQuerySpecification.new(limit: 10)
    assert_equal({limit: 10}, spec.options)
  end

  test "merge adds new options" do
    spec = Quo::RelationBackedQuerySpecification.new(limit: 10)
    new_spec = spec.merge(order: {id: :desc})
    assert_equal({limit: 10, order: {id: :desc}}, new_spec.options)
    assert_equal({limit: 10}, spec.options) # Original unchanged
  end

  test "merge overwrites existing options" do
    spec = Quo::RelationBackedQuerySpecification.new(limit: 10)
    new_spec = spec.merge(limit: 20)
    assert_equal({limit: 20}, new_spec.options)
    assert_equal({limit: 10}, spec.options) # Original unchanged
  end

  test "build class method creates new specification" do
    spec = Quo::RelationBackedQuerySpecification.build(limit: 10)
    assert_instance_of Quo::RelationBackedQuerySpecification, spec
    assert_equal({limit: 10}, spec.options)
  end

  test "blank class method returns empty specification" do
    spec = Quo::RelationBackedQuerySpecification.blank
    assert_instance_of Quo::RelationBackedQuerySpecification, spec
    assert_empty spec.options
  end

  test "apply_to with select option" do
    spec = Quo::RelationBackedQuerySpecification.new(select: ["id", "body"])
    result = spec.apply_to(@relation)

    assert_includes result.to_sql, "SELECT \"comments\".\"id\", \"comments\".\"body\""
    assert_not_includes result.to_sql, "\"comments\".\"post_id\""
  end

  test "apply_to with where option" do
    spec = Quo::RelationBackedQuerySpecification.new(where: {body: "test"})
    result = spec.apply_to(@relation)

    assert_includes result.to_sql, "WHERE \"comments\".\"body\" = 'test'"
  end

  test "apply_to with order option" do
    spec = Quo::RelationBackedQuerySpecification.new(order: {body: :desc})
    result = spec.apply_to(@relation)

    assert_includes result.to_sql, "ORDER BY \"comments\".\"body\" DESC"
  end

  test "apply_to with group option" do
    spec = Quo::RelationBackedQuerySpecification.new(group: ["post_id"])
    result = spec.apply_to(@relation)

    assert_includes result.to_sql, "GROUP BY \"comments\".\"post_id\""
  end

  test "apply_to with limit option" do
    spec = Quo::RelationBackedQuerySpecification.new(limit: 5)
    result = spec.apply_to(@relation)

    assert_includes result.to_sql, "LIMIT 5"
  end

  test "apply_to with offset option" do
    spec = Quo::RelationBackedQuerySpecification.new(offset: 10)
    result = spec.apply_to(@relation)

    assert_includes result.to_sql, "OFFSET 10"
  end

  test "apply_to with joins option" do
    spec = Quo::RelationBackedQuerySpecification.new(joins: :post)
    result = spec.apply_to(@relation)

    assert_includes result.to_sql, "INNER JOIN \"posts\" ON \"posts\".\"id\" = \"comments\".\"post_id\""
  end

  test "apply_to with left_outer_joins option" do
    spec = Quo::RelationBackedQuerySpecification.new(left_outer_joins: :post)
    result = spec.apply_to(@relation)

    assert_includes result.to_sql, "LEFT OUTER JOIN \"posts\" ON \"posts\".\"id\" = \"comments\".\"post_id\""
  end

  test "apply_to with includes option" do
    spec = Quo::RelationBackedQuerySpecification.new(includes: [:post])
    result = spec.apply_to(@relation)

    # The effect of includes is difficult to test through SQL, as it varies by Rails version
    # Instead, we'll check that the result contains the information needed for eager loading
    assert result.includes_values.include?(:post)
  end

  test "apply_to with preload option" do
    spec = Quo::RelationBackedQuerySpecification.new(preload: [:post])
    result = spec.apply_to(@relation)

    # preload doesn't modify the SQL directly, but adds to preload_values
    assert result.preload_values.include?(:post)
  end

  test "apply_to with eager_load option" do
    spec = Quo::RelationBackedQuerySpecification.new(eager_load: [:post])
    result = spec.apply_to(@relation)

    assert_includes result.to_sql, "LEFT OUTER JOIN \"posts\" ON \"posts\".\"id\" = \"comments\".\"post_id\""
  end

  test "apply_to with distinct option" do
    spec = Quo::RelationBackedQuerySpecification.new(distinct: true)
    result = spec.apply_to(@relation)

    assert_includes result.to_sql, "SELECT DISTINCT \"comments\".*"
  end

  test "apply_to with reorder option" do
    relation = @relation.order(:id)
    spec = Quo::RelationBackedQuerySpecification.new(reorder: {body: :desc})
    result = spec.apply_to(relation)

    assert_not_includes result.to_sql, "ORDER BY \"comments\".\"id\""
    assert_includes result.to_sql, "ORDER BY \"comments\".\"body\" DESC"
  end

  test "apply_to with extending option" do
    spec = Quo::RelationBackedQuerySpecification.new(extending: [Quo::Test::TestExtension])
    result = spec.apply_to(@relation)

    assert_respond_to result, :custom_method
    assert_equal "extended", result.custom_method
  end

  test "apply_to with unscope option" do
    relation = @relation.where(read: true).order(:id)
    spec = Quo::RelationBackedQuerySpecification.new(unscope: :where)
    result = spec.apply_to(relation)

    assert_not_includes result.to_sql, "WHERE"
    assert_includes result.to_sql, "ORDER BY"
  end

  test "apply_to with multiple options" do
    spec = Quo::RelationBackedQuerySpecification.new(
      select: ["id", "body"],
      where: {read: false},
      order: {id: :desc},
      limit: 5
    )
    result = spec.apply_to(@relation)

    assert_includes result.to_sql, "SELECT \"comments\".\"id\", \"comments\".\"body\""
    assert_includes result.to_sql, "WHERE \"comments\".\"read\" = 0"
    assert_includes result.to_sql, "ORDER BY \"comments\".\"id\" DESC"
    assert_includes result.to_sql, "LIMIT 5"
  end

  test "chaining multiple apply_to calls" do
    spec1 = Quo::RelationBackedQuerySpecification.new(where: {read: false})
    spec2 = Quo::RelationBackedQuerySpecification.new(limit: 5)

    # Apply specs sequentially
    result = spec2.apply_to(spec1.apply_to(@relation))

    assert_includes result.to_sql, "WHERE \"comments\".\"read\" = 0"
    assert_includes result.to_sql, "LIMIT 5"
  end

  test "using specification with a Quo query" do
    spec = Quo::RelationBackedQuerySpecification.new(where: {read: false}, limit: 5)
    query = UnreadCommentsQuery.new

    # Apply the specification to the query
    query_with_spec = query.with_specification(spec)
    result = query_with_spec.results

    assert_kind_of Quo::Results, result
    assert_includes query_with_spec.to_sql, "LIMIT 5"
  end
end
