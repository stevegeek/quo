# frozen_string_literal: true

require_relative "../test_helper"

class Quo::QueryComposerTest < ActiveSupport::TestCase
  test "composes when left is a AR backed query object and right is a AR backed query object" do
    left = NewCommentsForAuthorQuery.new(author_id: 1, page: 2, page_size: 25)
    # TODO: this is wierd, why should the other QO take irrelavent options to then have them be merged on compose?
    right = CommentNotSpamQuery.new(author_id: 2)
    composed = Quo::QueryComposer.new(left, right).compose

    assert_instance_of Quo::MergedQuery, composed
    assert_equal 2, composed.options[:author_id]
    assert_equal 25, composed.page_size
  end

  test "composes and correctly merges options for AR backed queries" do
    left = NewCommentsForAuthorQuery.new(author_id: 1, page: 2, page_size: 25)
    right = CommentNotSpamQuery.new(page_size: 50)
    composed = Quo::QueryComposer.new(left, right).compose
    assert_instance_of Quo::MergedQuery, composed
    assert_equal 1, composed.options[:author_id]
    assert_equal 50, composed.page_size
  end

  test "composes and generates valid SQL query" do
    left = NewCommentsForAuthorQuery.new(author_id: 1, page: 2, page_size: 25)
    right = CommentNotSpamQuery.new(page_size: 50) # Page size is 50 and page is 2 so offset is 50
    sql = "SELECT \"comments\".* FROM \"comments\" " \
      "INNER JOIN \"posts\" ON \"posts\".\"id\" = \"comments\".\"post_id\" " \
      "INNER JOIN \"authors\" ON \"authors\".\"id\" = \"posts\".\"author_id\" " \
      "WHERE \"comments\".\"read\" = 0 AND \"authors\".\"id\" = 1 AND (spam_score < 0.5) LIMIT 50 OFFSET 50"
    composed = Quo::QueryComposer.new(left, right).compose
    assert_equal sql, composed.to_sql
  end

  test "composes eager queries" do
    left = Quo::LoadedQuery.new([1, 2, 3], foo: 1)
    right = Quo::LoadedQuery.new([4, 5, 6], bar: 2)
    composed = Quo::QueryComposer.new(left, right).compose
    assert_instance_of Quo::MergedQuery, composed
    assert_equal 1, composed.options[:foo]
    assert_equal 2, composed.options[:bar]
    assert_equal [1, 2, 3, 4, 5, 6], composed.to_a
  end

  test "composes query and eager queries" do
    author = Author.create!(name: "John")
    post = Post.create!(title: "Post", author: author)
    records = [
      Comment.create!(post: post, body: "Comment 1", read: false),
      Comment.create!(post: post, body: "Comment 2", read: false),
      Comment.create!(post: post, body: "Comment 3", read: true)
    ]
    records << author
    records << post

    left = NewCommentsForAuthorQuery.new(author_id: author.id, page: 2, page_size: 1)
    right = Quo::LoadedQuery.new([4, 5, 6], bar: 2)
    composed = Quo::QueryComposer.new(left, right).compose
    assert_instance_of Quo::MergedQuery, composed
    assert_equal 1, composed.options[:author_id]
    assert_equal "Comment 2", composed.first.body # Page 2 so second comment
    assert_equal 6, composed.last

    # Compose right, left
    composed = Quo::QueryComposer.new(right, left).compose
    assert_instance_of Quo::MergedQuery, composed
    assert_equal 1, composed.options[:author_id]
    assert_equal "Comment 2", composed.last.body # Page 2 so second comment
    assert_equal 4, composed.first

    records.each(&:destroy!)
  end

  test "raises when invalid objects are composed" do
    assert_raises(ArgumentError) do
      Quo::QueryComposer.new(Object.new, Quo::LoadedQuery.new([])).compose
    end
  end
end
