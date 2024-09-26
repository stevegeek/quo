# frozen_string_literal: true

require_relative "../test_helper"

class Quo::ComposedQueryTest < ActiveSupport::TestCase
  def setup
    @a1 = Author.create!(name: "John")
    a2 = Author.create!(name: "Jane")
    p1 = Post.create!(title: "Post 1", author: @a1)
    p2 = Post.create!(title: "Post 2", author: a2)
    Comment.create!(post: p1, body: "abc", read: false)
    Comment.create!(post: p2, body: "def", read: false, spam_score: 0.8)
    Comment.create!(post: p1, body: "ghi", read: true, spam_score: 0.2)
    Comment.create!(post: p1, body: "jkl", read: false)

    @q1 = Quo::WrappedQuery.wrap(props: {since_date: Time}) do
      Comment.recent(since_date)
    end
    @q2 = Quo::WrappedQuery.wrap(props: {spam_score: Float}) do
      Comment.not_spam(spam_score)
    end

    @q_composed = Quo::ComposedQuery.composer(::UnreadCommentsQuery, ::Comment.joins(post: :author))
  end

  test "merges two active record queries" do
    assert_equal 4, ::Comment.count
    klass = Quo::ComposedQuery.composer(::Comment.recent, ::Comment.not_spam)
    assert_equal 3, klass.new.count
    assert_equal 2, klass.compose(::Comment.unread).new.count
  end

  test "merges two Quo::Query objects" do
    klass = @q1.compose(@q2)
    q = klass.new(since_date: 1.day.ago, spam_score: 0.5, page_size: 50)
    assert_equal 3, q.count
    assert_equal 0.5, q.spam_score
    assert_equal 50, q.page_size
    assert_equal 4, klass.new(since_date: 1.day.ago, spam_score: 0.9).count
  end

  test "merges two instances of Quo::Query objects" do
    query = Quo::ComposedQuery.merge_instances(@q1.new(since_date: 1.day.ago), @q2.new(spam_score: 0.5))
    assert_equal 3, query.count
  end

  test "merges two instances of Quo::Query objects with different values and takes rightmost" do
    klass = @q1.compose(@q2)
    q3 = klass.new(since_date: 1.day.ago, spam_score: 0.9)
    query = Quo::ComposedQuery.merge_instances(@q2.new(spam_score: 0.5), q3)
    assert_equal 4, query.count
  end

  test "composes and generates valid SQL query" do
    left = NewCommentsForAuthorQuery.new(author_id: 1, page: 2, page_size: 25)
    right = CommentNotSpamQuery.new(spam_score_threshold: 0.5, page_size: 50) # Page size is 50 and page is 2 so offset is 50
    sql = "SELECT \"comments\".* FROM \"comments\" " \
      "INNER JOIN \"posts\" ON \"posts\".\"id\" = \"comments\".\"post_id\" " \
      "INNER JOIN \"authors\" ON \"authors\".\"id\" = \"posts\".\"author_id\" " \
      "WHERE \"comments\".\"read\" = 0 AND \"authors\".\"id\" = 1 AND (spam_score IS NULL OR spam_score < 0.5) LIMIT 50 OFFSET 50"
    composed = left.merge(right)
    assert_equal sql, composed.to_sql
  end

  test "composes collection queries" do
    left = Quo::CollectionBackedQuery.wrap([1, 2, 3])
    right = Quo::CollectionBackedQuery.wrap([4, 5, 6])
    composed = Quo::ComposedQuery.composer(left, right)
    assert_equal [1, 2, 3, 4, 5, 6], composed.new.to_a
  end

  test "composes query and collection queries" do
    composed = NewCommentsForAuthorQuery.compose(Quo::CollectionBackedQuery.wrap([4, 5, 6]))
    q = composed.new(author_id: @a1.id)
    assert_kind_of Quo::ComposedQuery, q
    assert_equal 1, q.author_id
    assert_equal "abc", q.first.body
    assert_equal 6, q.last
  end

  test "composes collection and relation backed queries" do
    composed = Quo::CollectionBackedQuery.wrap([4, 5, 6]).compose(NewCommentsForAuthorQuery)
    q = composed.new(author_id: @a1.id)
    assert_kind_of Quo::ComposedQuery, q
    assert_equal 1, q.author_id
    assert_equal 4, q.first
    assert_equal "jkl", q.last.body
  end

  test "composes query and collection queries, with pagination" do
    composed = NewCommentsForAuthorQuery.compose(Quo::CollectionBackedQuery.wrap([4, 5, 6]))
    q = composed.new(author_id: @a1.id, page: 1, page_size: 2)
    # Apply pagination taking into account the collection content.
    # Result set is ("abc", "jkl"), (4, 5), (6)
    assert_kind_of Quo::ComposedQuery, q
    assert_equal 1, q.author_id
    assert_equal "abc", q.first.body
    assert_equal "jkl", q.last.body

    q = q.next_page_query
    assert_equal 4, q.first
    assert_equal 5, q.last
  end

  test "composes collection and relation backed queries, with pagination" do
    composed = Quo::CollectionBackedQuery.wrap([4, 5, 6]).compose(NewCommentsForAuthorQuery)
    q = composed.new(author_id: @a1.id, page: 2, page_size: 2)
    # Apply pagination taking into account the collection content.
    # Result set is (4, 5), (6, "abc"), ("jkl")
    assert_kind_of Quo::ComposedQuery, q
    assert_equal 1, q.author_id
    assert_equal 6, q.first
    assert_equal "abc", q.last.body

    q = q.next_page_query
    assert_equal "jkl", q.first.body
  end

  test "raises when invalid objects are composed" do
    assert_raises(ArgumentError) do
      Quo::ComposedQuery.composer(Object.new, Quo::CollectionBackedQuery.wrap([]))
    end
  end

  test "#inspect when 1 source is a query object subclass" do
    merged = Quo::ComposedQuery.composer(CommentNotSpamQuery, Quo::CollectionBackedQuery)
    assert_equal "Quo::ComposedQuery[CommentNotSpamQuery, Quo::CollectionBackedQuery]", merged.inspect
  end

  test "#inspect when 2 collection sources are provided" do
    merged = Quo::ComposedQuery.merge_instances(Quo::CollectionBackedQuery.wrap([]).new, Quo::CollectionBackedQuery.wrap([]).new)
    assert_kind_of Quo::ComposedQuery, merged
    assert_equal "Quo::ComposedQuery[Quo::CollectionBackedQuery, Quo::CollectionBackedQuery]", merged.inspect
  end

  test "#inspect when 1 source is a merged query" do
    nested = Quo::ComposedQuery.composer(CommentNotSpamQuery, UnreadCommentsQuery)
    merged = nested.compose(Quo::CollectionBackedQuery)
    assert_equal "Quo::ComposedQuery[Quo::ComposedQuery[CommentNotSpamQuery, UnreadCommentsQuery], Quo::CollectionBackedQuery]", merged.inspect
  end

  test "#copy makes a copy of this query object with different options" do
    q = @q1.new(since_date: 1.day.ago).merge(@q2.new(spam_score: 0.5))
    q_copy = q.copy(spam_score: 0.9)
    assert_kind_of Quo::ComposedQuery, q_copy
    assert_not_equal q, q_copy
    assert_equal 0.9, q_copy.spam_score
  end

  test "#order" do
    comments = @q_composed.new.order("authors.name" => :asc)
    assert_equal "Jane", comments.first.post.author.name
  end

  test "#limit" do
    assert_equal 1, @q_composed.new.limit(1).count
  end

  test "#group" do
    grouped = @q_composed.new.group("authors.id").count
    assert_equal 2, grouped.size
  end

  test "#includes" do
    comments = @q_composed.new.includes(post: :author)
    assert_equal "John", comments.first.post.author.name
  end

  test "#preload" do
    comments = @q_composed.new.preload(post: :author)
    assert_equal "John", comments.first.post.author.name
  end

  test "#select" do
    comments = @q_composed.new.select("id")
    c = comments.first
    assert_raises(ActiveModel::MissingAttributeError) { c.body }
    refute_nil c.id
  end

  test "#count" do
    assert_equal 3, @q_composed.new.count
  end

  test "#paged?" do
    assert ::UnreadCommentsQuery.new(page: 1, page_size: 1).merge(::Comment.joins(post: :author)).paged?
    refute @q_composed.new.paged?
  end

  test "#count with paging (count ignores paging)" do
    assert_equal 3, ::UnreadCommentsQuery.new(page_size: 1).merge(::Comment.joins(post: :author)).count
  end

  test "#page_count" do
    assert_equal 3, @q_composed.new.page_count
  end

  test "#page_count with paging" do
    assert_equal 1, ::UnreadCommentsQuery.new(page: 1, page_size: 1).merge(::Comment.joins(post: :author)).page_count
  end

  test "#count with selects" do
    assert_equal 3, Quo::ComposedQuery.merge_instances(
      Quo::WrappedQuery.wrap(Comment.where(read: false).joins(:post).select(:id, "posts.id")).new,
      ::UnreadCommentsQuery.new
    ).count
  end

  test "#to_a" do
    assert_instance_of Array, @q_composed.new.to_a
    assert_equal 3, @q_composed.new.to_a.size
  end

  test "#exists?/none?" do
    assert @q_composed.new.results.exists?
    refute @q_composed.new.results.none?
    assert @q1.new(since_date: 100.days.from_now).results.none?
  end

  test "#to_collection" do
    q = @q_composed.new
    collection = q.to_collection
    assert_kind_of Quo::CollectionBackedQuery, collection
    assert collection.collection?
    assert_equal 3, collection.count
  end

  test "#relation?/collection?" do
    assert @q_composed.new.relation?
    assert @q_composed.new.to_collection.collection?
    refute @q_composed.new.collection?
    assert Quo::ComposedQuery.composer(Quo::CollectionBackedQuery.wrap([]), ::Comment.joins(post: :author)).new.collection?
    refute Quo::ComposedQuery.composer(Quo::CollectionBackedQuery.wrap([]), ::Comment.joins(post: :author)).new.relation?
  end

  test "#first" do
    q = @q_composed.new
    assert_equal "abc", q.first.body
    assert_equal ["abc", "def"], q.first(2).map(&:body)

    q = q.copy(page: 1, page_size: 1)
    assert_equal "abc", q.first.body
    q = q.copy(page: 2, page_size: 1)
    assert_equal "def", q.first.body
    q = q.copy(page: 3, page_size: 1)
    assert_equal "jkl", q.first.body
    q = q.copy(page: 4, page_size: 1)
    assert_nil q.first
  end

  test ".call" do
    c = @q_composed.call
    assert_equal "abc", c.body
  end

  test ".call!" do
    assert_raises(ActiveRecord::RecordNotFound) { @q_composed.compose(::NewCommentsForAuthorQuery).call!(author_id: 1001) }
    assert_equal "abc", @q_composed.call!.body
  end

  test "#first!" do
    q = @q_composed.new
    assert_equal "abc", q.first!.body
    assert_raises(ActiveRecord::RecordNotFound) { @q_composed.compose(::NewCommentsForAuthorQuery).new(author_id: 1001).first! }

    q = q.copy(page: 1, page_size: 1)
    assert_equal "abc", q.first.body
    q = q.copy(page: 2, page_size: 1)
    assert_equal "def", q.first.body
    q = q.copy(page: 3, page_size: 1)
    assert_equal "jkl", q.first.body
    q = q.copy(page: 4, page_size: 1)
    assert_raises(ActiveRecord::RecordNotFound) { q.first! }
  end

  test "#last" do
    q = @q_composed.new
    assert_equal "jkl", q.last.body
    assert_equal ["def", "jkl"], q.last(2).map(&:body)
  end

  test "#transform" do
    q = @q_composed.new.transform do |c|
      c.body = "hello #{c.body} world"
      c
    end
    assert_equal "hello abc world", q.first.body
    assert_equal "hello jkl world", q.last.body
    assert_equal ["hello abc world", "hello def world"], q.first(2).map(&:body)
    assert_equal ["hello def world", "hello jkl world"], q.last(2).map(&:body)
  end

  test "#tranform copies to new query" do
    q = @q_composed.new.transform do |c|
      c.body = "hello #{c.body} world"
      c
    end
    q = q.select(:body)
    assert_equal "hello abc world", q.first.body
  end

  test "#transform?" do
    q = @q_composed.new.transform { |c| c }
    assert q.transform?
  end

  test "#to_sql" do
    klass = @q1.compose(@q2)
    assert_equal "SELECT \"comments\".* FROM \"comments\" WHERE (created_at > '2024-09-23 00:00:00') AND (spam_score IS NULL OR spam_score < 0.5)", klass.new(since_date: Time.parse("2024-09-23 00:00Z").utc, spam_score: 0.5).to_sql

    q = klass.new(since_date: 1.day.ago, spam_score: 0.5, page: 3, page_size: 12)
    assert q.to_sql.end_with?("LIMIT 12 OFFSET 24")
  end

  test "#unwrap" do
    ar = @q_composed.new.unwrap
    assert_kind_of ActiveRecord::Relation, ar

    assert_instance_of Array, @q_composed.new.to_collection.unwrap
  end

  test "#each" do
    q = @q_composed.new
    a = []
    e = q.results.each { |c| a << c.body }
    assert_kind_of Array, e
    assert_equal ["abc", "def", "jkl"], a
    assert_kind_of Comment, e.first
  end

  test "#map" do
    mapped = @q_composed.new.results.map.with_index do |c, i|
      c.body = "hello #{i}"
      c
    end
    assert_equal ["hello 0", "hello 1", "hello 2"], mapped.map(&:body)
  end
end
