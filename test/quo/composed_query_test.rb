# frozen_string_literal: true

require_relative "../test_helper"

class Quo::ComposedQueryTest < ActiveSupport::TestCase
  def setup
    a1 = Author.create!(name: "John")
    a2 = Author.create!(name: "Jane")
    p1 = Post.create!(title: "Post 1", author: a1)
    p2 = Post.create!(title: "Post 2", author: a2)
    Comment.create!(post: p1, body: "abc", read: false)
    Comment.create!(post: p2, body: "def", read: false, spam_score: 0.8)

    @q1 = Quo::WrappedQuery.wrap(props: {since_date: Time}) do
      Comment.recent(since_date)
    end
    @q2 = Quo::WrappedQuery.wrap(props: {spam_score: Float}) do
      Comment.not_spam(spam_score)
    end
  end

  test "merges two active record queries" do
    assert_equal 2, Comment.count
    klass = Quo::ComposedQuery.compose(Comment.recent, Comment.not_spam)
    assert_equal 1, klass.new.count
  end

  test "merges two Quo::Query objects" do
    klass = Quo::ComposedQuery.compose(@q1, @q2)
    assert_equal 1, klass.new(since_date: 1.day.ago, spam_score: 0.5).count
    assert_equal 2, klass.new(since_date: 1.day.ago, spam_score: 0.9).count
  end

  test "merges two instances of Quo::Query objects" do
    query = Quo::ComposedQuery.merge_instances(@q1.new(since_date: 1.day.ago), @q2.new(spam_score: 0.5))
    assert_equal 1, query.count
  end

  test "merges two instances of Quo::Query objects with different values and takes rightmost" do
    klass = Quo::ComposedQuery.compose(@q1, @q2)
    q3 = klass.new(since_date: 1.day.ago, spam_score: 0.9)
    query = Quo::ComposedQuery.merge_instances(@q2.new(spam_score: 0.5), q3)
    assert_equal 2, query.count
  end

  test "#inspect when 1 source is a query object subclass" do
    merged = Quo::ComposedQuery.compose(CommentNotSpamQuery, Quo::LoadedQuery)
    assert_equal "Quo::ComposedQuery[CommentNotSpamQuery, Quo::LoadedQuery]", merged.inspect
  end

  test "#inspect when 2 eager sources are provided" do
    merged = Quo::ComposedQuery.merge_instances(Quo::LoadedQuery.wrap([]).new, Quo::LoadedQuery.wrap([]).new)
    assert_equal "Quo::ComposedQuery[Quo::LoadedQuery, Quo::LoadedQuery]", merged.inspect
  end

  test "#inspect when 1 source is a merged query" do
    nested = Quo::ComposedQuery.compose(CommentNotSpamQuery, UnreadCommentsQuery)
    merged = Quo::ComposedQuery.compose(nested, Quo::LoadedQuery)
    assert_equal "Quo::ComposedQuery[Quo::ComposedQuery[CommentNotSpamQuery, UnreadCommentsQuery], Quo::LoadedQuery]", merged.inspect
  end
end


# # frozen_string_literal: true
#
# require_relative "../test_helper"
#
# class Quo::QueryComposerTest < ActiveSupport::TestCase
#   test "composes when left is a AR backed query object and right is a AR backed query object" do
#     left = NewCommentsForAuthorQuery.new(author_id: 1, page: 2, page_size: 25)
#     right = CommentNotSpamQuery.new
#     composed = Quo::QueryComposer.new(left, right).compose
#
#     assert_instance_of Quo::MergedQuery, composed
#     assert_equal 2, composed.author_id
#     assert_equal 25, composed.page_size
#   end
#   #
#   # test "composes and correctly merges options for AR backed queries" do
#   #   left = NewCommentsForAuthorQuery.new(author_id: 1, page: 2, page_size: 25)
#   #   right = CommentNotSpamQuery.new(page_size: 50)
#   #   composed = Quo::QueryComposer.new(left, right).compose
#   #   assert_instance_of Quo::MergedQuery, composed
#   #   assert_equal 1, composed.options[:author_id]
#   #   assert_equal 50, composed.page_size
#   # end
#   #
#   # test "composes and generates valid SQL query" do
#   #   left = NewCommentsForAuthorQuery.new(author_id: 1, page: 2, page_size: 25)
#   #   right = CommentNotSpamQuery.new(page_size: 50) # Page size is 50 and page is 2 so offset is 50
#   #   sql = "SELECT \"comments\".* FROM \"comments\" " \
#   #     "INNER JOIN \"posts\" ON \"posts\".\"id\" = \"comments\".\"post_id\" " \
#   #     "INNER JOIN \"authors\" ON \"authors\".\"id\" = \"posts\".\"author_id\" " \
#   #     "WHERE \"comments\".\"read\" = 0 AND \"authors\".\"id\" = 1 AND (spam_score < 0.5) LIMIT 50 OFFSET 50"
#   #   composed = Quo::QueryComposer.new(left, right).compose
#   #   assert_equal sql, composed.to_sql
#   # end
#   #
#   # test "composes eager queries" do
#   #   left = Quo::LoadedQuery.new([1, 2, 3], foo: 1)
#   #   right = Quo::LoadedQuery.new([4, 5, 6], bar: 2)
#   #   composed = Quo::QueryComposer.new(left, right).compose
#   #   assert_instance_of Quo::MergedQuery, composed
#   #   assert_equal 1, composed.options[:foo]
#   #   assert_equal 2, composed.options[:bar]
#   #   assert_equal [1, 2, 3, 4, 5, 6], composed.to_a
#   # end
#   #
#   # test "composes query and eager queries" do
#   #   author = Author.create!(name: "John")
#   #   post = Post.create!(title: "Post", author: author)
#   #   records = [
#   #     Comment.create!(post: post, body: "Comment 1", read: false),
#   #     Comment.create!(post: post, body: "Comment 2", read: false),
#   #     Comment.create!(post: post, body: "Comment 3", read: true)
#   #   ]
#   #   records << author
#   #   records << post
#   #
#   #   left = NewCommentsForAuthorQuery.new(author_id: author.id, page: 2, page_size: 1)
#   #   right = Quo::LoadedQuery.new([4, 5, 6], bar: 2)
#   #   composed = Quo::QueryComposer.new(left, right).compose
#   #   assert_instance_of Quo::MergedQuery, composed
#   #   assert_equal 1, composed.options[:author_id]
#   #   assert_equal "Comment 2", composed.first.body # Page 2 so second comment
#   #   assert_equal 6, composed.last
#   #
#   #   # Compose right, left
#   #   composed = Quo::QueryComposer.new(right, left).compose
#   #   assert_instance_of Quo::MergedQuery, composed
#   #   assert_equal 1, composed.options[:author_id]
#   #   assert_equal "Comment 2", composed.last.body # Page 2 so second comment
#   #   assert_equal 4, composed.first
#   #
#   #   records.each(&:destroy!)
#   # end
#   #
#   # test "raises when invalid objects are composed" do
#   #   assert_raises(ArgumentError) do
#   #     Quo::QueryComposer.new(Object.new, Quo::LoadedQuery.new([])).compose
#   #   end
#   # end
# end
