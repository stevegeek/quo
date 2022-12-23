# frozen_string_literal: true

require_relative "../test_helper"

class Quo::MergedQueryTest < ActiveSupport::TestCase
  test "#to_s when 1 source is a query object subclass" do
    nested = NewCommentsForAuthorQuery.new(author_id: 1)
    merged = Quo::MergedQuery.new(NewCommentsForAuthorQuery, nested, Quo::LoadedQuery.new(nil))
    assert_equal "Quo::MergedQuery[NewCommentsForAuthorQuery, Quo::LoadedQuery]", merged.to_s
  end

  test "#to_s when 2 eager sources are provided" do
    merged = Quo::MergedQuery.new(NewCommentsForAuthorQuery, Quo::LoadedQuery.new(nil), Quo::LoadedQuery.new(nil))
    assert_equal "Quo::MergedQuery[Quo::LoadedQuery, Quo::LoadedQuery]", merged.to_s
  end

  test "#to_s when 1 source is a merged query" do
    nested = Quo::MergedQuery.new(NewCommentsForAuthorQuery, Quo::LoadedQuery.new(nil), Quo::LoadedQuery.new(nil))
    merged = Quo::MergedQuery.new(NewCommentsForAuthorQuery, nested, Quo::LoadedQuery.new(nil))
    assert_equal "Quo::MergedQuery[Quo::MergedQuery[Quo::LoadedQuery, Quo::LoadedQuery], Quo::LoadedQuery]", merged.to_s
  end
end
