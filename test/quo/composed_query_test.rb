# frozen_string_literal: true

require "test_helper"

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

    @q1 = Quo::RelationBackedQuery.wrap(props: {since_date: Time}) do
      Comment.recent(since_date)
    end
    @q2 = Quo::RelationBackedQuery.wrap(props: {spam_score: Float}) do
      Comment.not_spam(spam_score)
    end

    @q_composed = Quo::RelationBackedQuery.wrap(::UnreadCommentsQuery.new).compose(::Comment.joins(post: :author))
  end

  test "merges two active record queries" do
    assert_equal 4, ::Comment.count
    klass = Quo::RelationBackedQuery.wrap(::Comment.recent).compose(::Comment.not_spam)
    assert_equal 3, klass.new.results.count
    assert_equal 2, klass.compose(::Comment.unread).new.results.count
  end

  test "merged result is a Quo Query and inherits from configured base class" do
    klass = Quo::RelationBackedQuery.wrap(::Comment.recent).compose(::Comment.not_spam)
    assert_equal ApplicationRelationQuery, klass.superclass
    assert_equal "relation", klass.new.hello
  end

  test "merges two Quo::Query objects" do
    klass = @q1.compose(@q2)
    q = klass.new(since_date: 1.day.ago, spam_score: 0.5, page_size: 50)
    assert_equal 3, q.results.count
    assert_equal 0.5, q.spam_score
    assert_equal 50, q.page_size
    assert_equal 4, klass.new(since_date: 1.day.ago, spam_score: 0.9).results.count
  end

  test "merges two instances of Quo::Query objects" do
    query = @q1.new(since_date: 1.day.ago).merge(@q2.new(spam_score: 0.5))
    assert_equal 3, query.results.count
  end

  test "merges two instances of Quo::Query objects — each operand keeps its own props (v2)" do
    # In Quo 2.x, instance composition does NOT fan props down from a synthesized
    # parent class. Each operand keeps its own constructor-time props and
    # contributes its own filter to the merged AR relation. So
    #   q2(spam_score: 0.5) + q3(spam_score: 0.9)
    # produces `(spam_score < 0.5) AND (spam_score < 0.9)` — i.e. the more
    # restrictive filter wins, not "rightmost wins".
    klass = @q1.compose(@q2)
    q3 = klass.new(since_date: 1.day.ago, spam_score: 0.9)
    query = @q2.new(spam_score: 0.5).merge(q3)
    assert_equal 3, query.results.count
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

  test "composes relation queries with + operator at class level" do
    composed = @q1 + @q2
    q = composed.new(since_date: 1.day.ago, spam_score: 0.5)
    assert_equal 3, q.results.count
    assert_instance_of Class, composed
    assert composed < Quo::RelationBackedQuery
  end

  test "composes collection queries" do
    left = Quo::CollectionBackedQuery.wrap([1, 2, 3])
    right = Quo::CollectionBackedQuery.wrap([4, 5, 6])
    composed = left + right
    assert_equal "collection", composed.new.hello
    assert_equal [1, 2, 3, 4, 5, 6], composed.new.results.to_a
  end

  test "composes query and collection queries" do
    composed = NewCommentsForAuthorQuery.compose(Quo::CollectionBackedQuery.wrap([4, 5, 6]))
    q = composed.new(author_id: @a1.id)
    assert_kind_of Quo::ComposedQuery, q
    assert_equal 1, q.author_id
    assert_equal "abc", q.results.first.body
    assert_equal 6, q.results.last
  end

  test "composes collection and relation backed queries" do
    composed = Quo::CollectionBackedQuery.wrap([4, 5, 6]).compose(NewCommentsForAuthorQuery)
    q = composed.new(author_id: @a1.id)
    assert_kind_of Quo::ComposedQuery, q
    assert_equal 1, q.author_id
    assert_equal 4, q.results.first
    assert_equal "jkl", q.results.last.body
  end

  test "composes query and collection queries, with pagination" do
    composed = NewCommentsForAuthorQuery.compose(Quo::CollectionBackedQuery.wrap([4, 5, 6]))
    q = composed.new(author_id: @a1.id, page: 1, page_size: 2)
    # Apply pagination taking into account the collection content.
    # Result set is ("abc", "jkl"), (4, 5), (6)
    assert_kind_of Quo::ComposedQuery, q
    assert_equal 1, q.author_id
    assert_equal "abc", q.results.first.body
    assert_equal "jkl", q.results.last.body

    q = q.next_page_query
    assert_equal 4, q.results.first
    assert_equal 5, q.results.last
  end

  test "composes collection and relation backed queries, with pagination" do
    composed = Quo::CollectionBackedQuery.wrap([4, 5, 6]).compose(NewCommentsForAuthorQuery)
    q = composed.new(author_id: @a1.id, page: 2, page_size: 2)
    # Apply pagination taking into account the collection content.
    # Result set is (4, 5), (6, "abc"), ("jkl")
    assert_kind_of Quo::ComposedQuery, q
    assert_equal 1, q.author_id
    assert_equal 6, q.results.first
    assert_equal "abc", q.results.last.body

    q = q.next_page_query
    assert_equal "jkl", q.results.first.body
  end

  test "raises when invalid objects are composed" do
    assert_raises(ArgumentError) do
      Quo::Composing.composer(Quo::CollectionBackedQuery, Object.new, Quo::CollectionBackedQuery.wrap([]))
    end
  end

  test "#inspect when 1 source is a query object subclass" do
    merged = CommentNotSpamQuery.compose(Quo::CollectionBackedQuery)
    assert_equal "ApplicationRelationQuery<Quo::ComposedQuery>[CommentNotSpamQuery, Quo::CollectionBackedQuery]", merged.inspect
  end

  test "#inspect when 2 collection sources are provided" do
    # In Quo 2.x, instance composition returns a value-form composed query
    # (Quo::ComposedCollectionBackedQuery for two collection operands), not
    # an anonymous subclass that mixes in Quo::ComposedQuery. The inspect
    # output reflects the new concrete class.
    merged = Quo::CollectionBackedQuery.wrap([]).new.merge(Quo::CollectionBackedQuery.wrap([]).new)
    assert_kind_of Quo::ComposedCollectionBackedQuery, merged
    assert_kind_of Quo::Query, merged
    assert_includes merged.inspect, "Quo::ComposedCollectionBackedQuery"
  end

  test "#inspect when 1 source is a merged query" do
    nested = CommentNotSpamQuery.compose(UnreadCommentsQuery)
    merged = nested.compose(Quo::CollectionBackedQuery)
    assert_equal "ApplicationRelationQuery<Quo::ComposedQuery>[ApplicationRelationQuery<Quo::ComposedQuery>[CommentNotSpamQuery, UnreadCommentsQuery], Quo::CollectionBackedQuery]", merged.inspect
  end

  test "#copy on a composed instance overrides own props and fans operand props (v2)" do
    # In Quo 2.x, the composed instance's own props are
    # (_left, _right, _joins, page, page_size, _specification).
    # Overrides for own props go to the standard Literal copy.
    # Overrides for OTHER props (declared on a leaf operand) are walked
    # right-first into the operand tree and applied to the first matching
    # operand. Unknown props raise.
    q = @q1.new(since_date: 1.day.ago).merge(@q2.new(spam_score: 0.5))

    # Own-prop override
    q_paged = q.copy(page: 3)
    assert_kind_of Quo::ComposedRelationBackedQuery, q_paged
    assert_equal 3, q_paged.page

    # Operand-prop override: spam_score is on @q2 (right operand)
    q_score = q.copy(spam_score: 0.9)
    assert_kind_of Quo::ComposedRelationBackedQuery, q_score
    assert_equal 0.9, q_score._right.spam_score
    # Left operand untouched
    assert_equal 1.day.ago.to_date, q_score._left.since_date.to_date

    # Unknown prop raises (matches Literal::Struct semantics)
    assert_raises(ArgumentError) { q.copy(nope_not_a_prop: 1) }
  end

  test "#count" do
    assert_equal 3, @q_composed.new.results.count
  end

  test "#paged?" do
    assert ::UnreadCommentsQuery.new(page: 1, page_size: 1).merge(::Comment.joins(post: :author)).paged?
    refute @q_composed.new.paged?
  end

  test "#count with paging (count ignores paging)" do
    assert_equal 3, ::UnreadCommentsQuery.new(page_size: 1).merge(::Comment.joins(post: :author)).results.count
  end

  test "#page_count" do
    assert_equal 3, @q_composed.new.results.page_count
  end

  test "#page_count with paging" do
    assert_equal 1, ::UnreadCommentsQuery.new(page: 1, page_size: 1).merge(::Comment.joins(post: :author)).results.page_count
  end

  test "#count with selects" do
    assert_equal 3, Quo::RelationBackedQuery.wrap(Comment.where(read: false).joins(:post).select(:id, "posts.id")).new.merge(
      ::UnreadCommentsQuery.new
    ).results.count
  end

  test "#relation?/collection?" do
    assert @q_composed.new.relation?
    assert @q_composed.new.to_collection.collection?
    refute @q_composed.new.collection?
    assert Quo::CollectionBackedQuery.wrap([]).compose(::Comment.joins(post: :author)).new.collection?
    refute Quo::CollectionBackedQuery.wrap([]).compose(::Comment.joins(post: :author)).new.relation?
  end

  test "#first" do
    q = @q_composed.new
    results = q.results
    assert_equal "abc", results.first.body
    assert_equal ["abc", "def"], results.first(2).map(&:body)

    results = q.copy(page: 1, page_size: 1).results
    assert_equal "abc", results.first.body
    results = q.copy(page: 2, page_size: 1).results
    assert_equal "def", results.first.body
    results = q.copy(page: 3, page_size: 1).results
    assert_equal "jkl", results.first.body
    results = q.copy(page: 4, page_size: 1).results
    assert_nil results.first
  end

  test "#first!" do
    q = @q_composed.new
    results = q.results
    assert_equal "abc", results.first!.body
    assert_raises(ActiveRecord::RecordNotFound) { @q_composed.compose(::NewCommentsForAuthorQuery).new(author_id: 1001).results.first! }

    results = q.copy(page: 1, page_size: 1).results
    assert_equal "abc", results.first.body
    results = q.copy(page: 2, page_size: 1).results
    assert_equal "def", results.first.body
    results = q.copy(page: 3, page_size: 1).results
    assert_equal "jkl", results.first.body
    results = q.copy(page: 4, page_size: 1).results
    assert_raises(ActiveRecord::RecordNotFound) { results.first! }
  end

  test "#last" do
    q = @q_composed.new
    assert_equal "jkl", q.results.last.body
    assert_equal ["def", "jkl"], q.results.last(2).map(&:body)
  end

  test "#transform" do
    q = @q_composed.new.transform do |c|
      c.body = "hello #{c.body} world"
      c
    end
    results = q.results
    assert_equal "hello abc world", results.first.body
    assert_equal "hello jkl world", results.last.body
    assert_equal ["hello abc world", "hello def world"], results.first(2).map(&:body)
    assert_equal ["hello def world", "hello jkl world"], results.last(2).map(&:body)
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

  test "merged query applies specifications when composing relation backed queries" do
    query_with_order = Quo::RelationBackedQuery.wrap(Comment.all).new.order(:created_at)
    query_with_joins = Quo::RelationBackedQuery.wrap(Comment.all).new.joins(post: :author)

    # Merge the queries
    merged_query = query_with_order.merge(query_with_joins)

    # Verify that the query gets executed properly with both specifications
    sql = merged_query.to_sql
    assert_match(/"comments"\."created_at" ASC/, sql)
    assert_match(/INNER JOIN "authors"/, sql)
  end

  # ---- Copy fan-out (v2 instance composition) -----------------------------

  test "copy fan-out: prop on right operand only — applies to right" do
    q = @q1.new(since_date: 1.day.ago).merge(@q2.new(spam_score: 0.5))
    out = q.copy(spam_score: 0.9)

    assert_equal 0.9, out._right.spam_score
    assert_equal 0.5, q._right.spam_score # original is immutable
  end

  test "copy fan-out: prop on left operand only — applies to left" do
    q = @q1.new(since_date: 1.day.ago).merge(@q2.new(spam_score: 0.5))
    out = q.copy(since_date: 2.days.ago)

    assert_equal 2.days.ago.to_date, out._left.since_date.to_date
    assert_equal 1.day.ago.to_date, q._left.since_date.to_date # original immutable
  end

  test "copy fan-out: right wins when prop is on both operands" do
    # Two leaves that BOTH declare :spam_score
    left = @q2.new(spam_score: 0.4)
    right = @q2.new(spam_score: 0.6)
    composed = left.merge(right)

    out = composed.copy(spam_score: 0.9)

    assert_equal 0.4, out._left.spam_score, "left operand untouched"
    assert_equal 0.9, out._right.spam_score, "right operand updated"
  end

  test "copy fan-out: recurses into a composed operand" do
    # Tree: q1 + (q1 + q2) — :spam_score lives on the deepest leaf
    inner = @q1.new(since_date: 1.day.ago).merge(@q2.new(spam_score: 0.5))
    outer = @q1.new(since_date: 1.day.ago).merge(inner)

    out = outer.copy(spam_score: 0.9)

    # The override should reach the q2 instance deep inside `inner`
    assert_equal 0.9, out._right._right.spam_score
  end

  test "copy fan-out: unknown prop raises" do
    q = @q1.new(since_date: 1.day.ago).merge(@q2.new(spam_score: 0.5))
    assert_raises(ArgumentError) { q.copy(definitely_not_a_prop: 1) }
  end

  test "copy fan-out: AR::Relation operand is skipped over" do
    # Right is an AR::Relation, not a Quo::Query — it has no Quo props.
    composed = @q2.new(spam_score: 0.5).merge(Comment.all)
    out = composed.copy(spam_score: 0.9)

    # Override should land on the left Quo::Query operand
    assert_equal 0.9, out._left.spam_score
  end

  test "copy fan-out: own-prop and fan-prop overrides combine cleanly" do
    q = @q1.new(since_date: 1.day.ago).merge(@q2.new(spam_score: 0.5))
    out = q.copy(page: 3, spam_score: 0.9)

    assert_equal 3, out.page
    assert_equal 0.9, out._right.spam_score
  end
end
