# frozen_string_literal: true

require "test_helper"

module Quo
  # Test module for the extending test
  module TestExtendingModule; end

  class RelationBackedQuerySpecificationExtendedTest < ActiveSupport::TestCase
    test "#has? returns true when option exists" do
      spec = Quo::RelationBackedQuerySpecification.new(where: {id: 1})
      assert spec.has?(:where)
      refute spec.has?(:order)
    end

    test "#[] returns option value" do
      spec = Quo::RelationBackedQuerySpecification.new(where: {id: 1})
      assert_equal({id: 1}, spec[:where])
      assert_nil spec[:order]
    end

    test "#select creates specification with select option" do
      spec = Quo::RelationBackedQuerySpecification.new
      new_spec = spec.select(:id, :name)
      assert_equal [:id, :name], new_spec.options[:select]
    end

    test "#where creates specification with where option" do
      spec = Quo::RelationBackedQuerySpecification.new
      new_spec = spec.where(id: 1)
      assert_equal({id: 1}, new_spec.options[:where])
    end

    test "#order creates specification with order option" do
      spec = Quo::RelationBackedQuerySpecification.new
      new_spec = spec.order(:created_at)
      assert_equal :created_at, new_spec.options[:order]
    end

    test "#group creates specification with group option" do
      spec = Quo::RelationBackedQuerySpecification.new
      new_spec = spec.group(:category_id)
      assert_equal [:category_id], new_spec.options[:group]
    end

    test "#limit creates specification with limit option" do
      spec = Quo::RelationBackedQuerySpecification.new
      new_spec = spec.limit(10)
      assert_equal 10, new_spec.options[:limit]
    end

    test "#offset creates specification with offset option" do
      spec = Quo::RelationBackedQuerySpecification.new
      new_spec = spec.offset(20)
      assert_equal 20, new_spec.options[:offset]
    end

    test "#joins creates specification with joins option" do
      spec = Quo::RelationBackedQuerySpecification.new
      new_spec = spec.joins(:posts)
      assert_equal :posts, new_spec.options[:joins]
    end

    test "#left_outer_joins creates specification with left_outer_joins option" do
      spec = Quo::RelationBackedQuerySpecification.new
      new_spec = spec.left_outer_joins(:posts)
      assert_equal :posts, new_spec.options[:left_outer_joins]
    end

    test "#includes creates specification with includes option" do
      spec = Quo::RelationBackedQuerySpecification.new
      new_spec = spec.includes(:posts, :comments)
      assert_equal [:posts, :comments], new_spec.options[:includes]
    end

    test "#preload creates specification with preload option" do
      spec = Quo::RelationBackedQuerySpecification.new
      new_spec = spec.preload(:posts, :comments)
      assert_equal [:posts, :comments], new_spec.options[:preload]
    end

    test "#eager_load creates specification with eager_load option" do
      spec = Quo::RelationBackedQuerySpecification.new
      new_spec = spec.eager_load(:posts, :comments)
      assert_equal [:posts, :comments], new_spec.options[:eager_load]
    end

    test "#distinct creates specification with distinct option" do
      spec = Quo::RelationBackedQuerySpecification.new
      new_spec = spec.distinct
      assert_equal true, new_spec.options[:distinct]

      # Test with explicit value
      new_spec = spec.distinct(false)
      assert_equal false, new_spec.options[:distinct]
    end

    test "#reorder creates specification with reorder option" do
      spec = Quo::RelationBackedQuerySpecification.new
      new_spec = spec.reorder(:updated_at)
      assert_equal :updated_at, new_spec.options[:reorder]
    end

    test "#extending creates specification with extending option" do
      spec = Quo::RelationBackedQuerySpecification.new
      new_spec = spec.extending(Quo::TestExtendingModule)
      assert_equal [Quo::TestExtendingModule], new_spec.options[:extending]
    end

    test "#unscope creates specification with unscope option" do
      spec = Quo::RelationBackedQuerySpecification.new
      new_spec = spec.unscope(:where)
      assert_equal [:where], new_spec.options[:unscope]
    end

    test ".build creates a new specification from options" do
      options = {where: {id: 1}, order: :created_at}
      spec = Quo::RelationBackedQuerySpecification.build(options)

      assert_instance_of Quo::RelationBackedQuerySpecification, spec
      assert_equal options, spec.options
    end

    test ".blank returns an empty specification" do
      spec = Quo::RelationBackedQuerySpecification.blank
      assert_instance_of Quo::RelationBackedQuerySpecification, spec
      assert_equal({}, spec.options)

      # Test caching
      assert_equal spec.object_id, Quo::RelationBackedQuerySpecification.blank.object_id
    end

    test "#apply_to applies options to a relation" do
      # Create a specification with a subset of options to avoid
      # non-existent associations in the test database
      spec = Quo::RelationBackedQuerySpecification.new(
        select: [:id, :name],
        where: {id: 1},
        order: :created_at,
        limit: 10,
        offset: 20,
        distinct: true,
        reorder: :created_at
      )

      relation = Author.all
      result = spec.apply_to(relation)

      # Check SQL to ensure options were applied
      sql = result.to_sql
      assert_match(/SELECT DISTINCT/, sql)
      # Check for id and name columns in the SELECT clause instead of *
      assert_match(/"authors"\."id"/, sql)
      assert_match(/"authors"\."name"/, sql)
      assert_match(/"authors"\."id" = 1/, sql)
      assert_match(/ORDER BY "authors"\."created_at"/, sql)
      assert_match(/LIMIT 10/, sql)
      assert_match(/OFFSET 20/, sql)
    end

    test "#apply_to applies selected options to a relation" do
      # Test each option type separately to avoid dependency issues

      # Test joins
      joins_spec = Quo::RelationBackedQuerySpecification.new(joins: :posts)
      joins_result = joins_spec.apply_to(Author.all)
      assert_match(/INNER JOIN "posts"/, joins_result.to_sql)

      # Test left_outer_joins
      left_joins_spec = Quo::RelationBackedQuerySpecification.new(left_outer_joins: :posts)
      left_joins_result = left_joins_spec.apply_to(Author.all)
      assert_match(/LEFT OUTER JOIN "posts"/, left_joins_result.to_sql)

      # Test group
      group_spec = Quo::RelationBackedQuerySpecification.new(group: [:id])
      group_result = group_spec.apply_to(Author.all)
      assert_match(/GROUP BY "authors"\."id"/, group_result.to_sql)

      # Test unscope
      unscope_spec = Quo::RelationBackedQuerySpecification.new(
        where: {id: 1},
        unscope: [:where]
      )
      unscope_result = unscope_spec.apply_to(Author.where(id: 2))
      refute_match(/WHERE/, unscope_result.to_sql)
    end
  end
end
