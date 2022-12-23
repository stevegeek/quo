# frozen_string_literal: true

require_relative "../test_helper"

class Quo::QueryTest < ActiveSupport::TestCase
  def setup
    a1 = Author.create!(name: "John")
    a2 = Author.create!(name: "Jane")
    p1 = Post.create!(title: "Post 1", author: a1)
    p2 = Post.create!(title: "Post 2", author: a2)
    Comment.create!(post: p1, body: "abc", read: false)
    Comment.create!(post: p2, body: "def", read: false)
  end

  test "#copy makes a copy of this query object with different options" do
    q = NewCommentsForAuthorQuery.new(author_id: 1)
    q_copy = q.copy(author_id: 2)
    assert_instance_of NewCommentsForAuthorQuery, q_copy
    assert_not_equal q, q_copy
    assert_equal 2, q_copy.options[:author_id]
  end

  test "#order" do
    q = UnreadCommentsQuery.new + Comment.joins(post: :author)
    comments = q.order("authors.name" => :asc)
    assert_equal "Jane", comments.first.post.author.name
  end

  test "#limit" do
    assert_equal 1, UnreadCommentsQuery.new.limit(1).count
  end

  test "#group" do
    q = UnreadCommentsQuery.new + Comment.joins(post: :author)
    grouped = q.group("authors.id").count
    assert_equal 2, grouped.size
  end

  test "#includes" do
    q = UnreadCommentsQuery.new
    comments = q.includes(post: :author)
    assert_equal "John", comments.first.post.author.name
  end

  test "#preload" do
    q = UnreadCommentsQuery.new
    comments = q.preload(post: :author)
    assert_equal "John", comments.first.post.author.name
  end

  test "#select" do
    q = UnreadCommentsQuery.new
    comments = q.select("id")
    c = comments.first
    assert_raises(ActiveModel::MissingAttributeError) { c.body }
    refute_nil c.id
  end

  test "#count" do
    assert_equal 2, UnreadCommentsQuery.new.count
  end

  test "#paged?" do
    assert UnreadCommentsQuery.new(page: 1, page_size: 1).paged?
    refute UnreadCommentsQuery.new.paged?
  end

  test "#count with paging" do
    assert_equal 2, UnreadCommentsQuery.new(page_size: 1).count
  end

  test "#page_count" do
    assert_equal 2, UnreadCommentsQuery.new.page_count
  end

  test "#page_count with paging" do
    assert_equal 1, UnreadCommentsQuery.new(page: 1, page_size: 1).page_count
  end

  test "#to_a" do
    assert_instance_of Array, UnreadCommentsQuery.new.to_a
    assert_equal 2, UnreadCommentsQuery.new.to_a.size
  end

  test "#exists?/none?" do
    assert UnreadCommentsQuery.new.exists?
    refute UnreadCommentsQuery.new.none?
    assert NewCommentsForAuthorQuery.new(author_id: 1001).none?
  end

  test "#to_eager" do
    q = UnreadCommentsQuery.new
    eager = q.to_eager
    assert_instance_of Quo::LoadedQuery, eager
    assert_equal 2, eager.count
  end

  test "#relation?/eager?" do
    assert UnreadCommentsQuery.new.relation?
    assert UnreadCommentsQuery.new.to_eager.eager?
    refute UnreadCommentsQuery.new.eager?
    assert Quo::LoadedQuery.new(nil).eager?
    refute Quo::LoadedQuery.new(nil).relation?
  end

  test "#first" do
    q = UnreadCommentsQuery.new
    assert_equal "abc", q.first.body
    assert_equal ["abc", "def"], q.first(2).map(&:body)

    q = q.copy(page: 1, page_size: 1)
    assert_equal "abc", q.first.body
    q = q.copy(page: 2, page_size: 1)
    assert_equal "def", q.first.body
    q = q.copy(page: 3, page_size: 1)
    assert_nil q.first
  end

  test ".call" do
    c = UnreadCommentsQuery.call
    assert_equal "abc", c.body
    assert_nil NewCommentsForAuthorQuery.call(author_id: 1001)
  end

  test ".call!" do
    c = UnreadCommentsQuery.call
    assert_equal "abc", c.body
  end

  test "#first!" do
    q = UnreadCommentsQuery.new
    assert_equal "abc", q.first!.body
    assert_raises(ActiveRecord::RecordNotFound) { NewCommentsForAuthorQuery.new(author_id: 1001).first! }

    q = q.copy(page: 1, page_size: 1)
    assert_equal "abc", q.first.body
    q = q.copy(page: 2, page_size: 1)
    assert_equal "def", q.first.body
    q = q.copy(page: 3, page_size: 1)
    assert_raises(ActiveRecord::RecordNotFound) { q.first! }
  end

  test ".call! raises when no item exists" do
    assert_raises(ActiveRecord::RecordNotFound) { NewCommentsForAuthorQuery.call!(author_id: 1001) }
  end

  test "#last" do
    q = UnreadCommentsQuery.new
    assert_equal "def", q.last.body
    assert_equal ["abc", "def"], q.last(2).map(&:body)
  end

  test "#transform" do
    q = UnreadCommentsQuery.new.transform do |c|
      c.body = "hello #{c.body} world"
      c
    end
    assert_equal "hello abc world", q.first.body
    assert_equal "hello def world", q.last.body
    assert_equal ["hello abc world", "hello def world"], q.first(2).map(&:body)
  end

  test "#tranform copies to new query" do
    q = UnreadCommentsQuery.new.transform do |c|
      c.body = "hello #{c.body} world"
      c
    end
    q = q.select(:body)
    assert_equal "hello abc world", q.first.body
  end

  test "#transform?" do
    q = UnreadCommentsQuery.new.transform { |c| c }
    assert q.transform?
  end

  test "#to_sql" do
    q = NewCommentsForAuthorQuery.new(author_id: 1)
    assert_equal "SELECT \"comments\".* FROM \"comments\" INNER JOIN \"posts\" ON \"posts\".\"id\" = \"comments\".\"post_id\" INNER JOIN \"authors\" ON \"authors\".\"id\" = \"posts\".\"author_id\" WHERE \"comments\".\"read\" = 0 AND \"authors\".\"id\" = 1", q.to_sql

    q = NewCommentsForAuthorQuery.new(author_id: 1, page: 3, page_size: 12)
    assert q.to_sql.end_with?("\"authors\".\"id\" = 1 LIMIT 12 OFFSET 24")
  end

  test "#unwrap" do
    q = NewCommentsForAuthorQuery.new(author_id: 1)
    ar = q.unwrap
    assert_kind_of ActiveRecord::Relation, ar

    assert_instance_of Array, q.to_eager.unwrap
  end

  test "#each" do
    q = UnreadCommentsQuery.new
    a = []
    e = q.each { |c| a << c.body }
    assert_kind_of Array, e
    assert_equal ["abc", "def"], a
    assert_kind_of Comment, e.first
  end

  test "#map" do
    mapped = UnreadCommentsQuery.new.results.map.with_index do |c, i|
      c.body = "hello #{i} world"
      c
    end
    assert_equal ["hello 0 world", "hello 1 world"], mapped.map(&:body)
  end
end
