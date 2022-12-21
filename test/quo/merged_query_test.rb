# frozen_string_literal: true

require_relative "../test_helper"

class Quo::MergedQueryTest < ActiveSupport::TestCase
  test "#to_s when 1 source is a query object subclass" do
    nested = NewCommentsForAuthorQuery.new(author_id: 1)
    merged = Quo::MergedQuery.new(NewCommentsForAuthorQuery, nested, Quo::EagerQuery.new)
    assert_equal "Quo::MergedQuery[NewCommentsForAuthorQuery, Quo::EagerQuery]", merged.to_s
  end

  test "#to_s when 2 eager sources are provided" do
    merged = Quo::MergedQuery.new(NewCommentsForAuthorQuery, Quo::EagerQuery.new, Quo::EagerQuery.new)
    assert_equal "Quo::MergedQuery[Quo::EagerQuery, Quo::EagerQuery]", merged.to_s
  end

  test "#to_s when 1 source is a merged query" do
    nested = Quo::MergedQuery.new(NewCommentsForAuthorQuery, Quo::EagerQuery.new, Quo::EagerQuery.new)
    merged = Quo::MergedQuery.new(NewCommentsForAuthorQuery, nested, Quo::EagerQuery.new)
    assert_equal "Quo::MergedQuery[Quo::MergedQuery[Quo::EagerQuery, Quo::EagerQuery], Quo::EagerQuery]", merged.to_s
  end
end
