# Query Composition Reference

> **Targets Quo `~> 2.0`.**

Quo lets you combine query objects using `+` (alias of `compose` /
`merge`). It supports two composition modes that look identical but do
different work. **Choose deliberately** — picking the wrong one is the
single most common Quo perf footgun.

## The two composition modes

### 1. Class composition — `SomeClass + OtherClass`

When the operands are query **classes**, `+` returns a new Class. This is
useful for *defining a new named query type* in terms of existing ones.

```ruby
RecentNonSpamComments = RecentCommentsQuery + NonSpamCommentsQuery

# Or as a real subclass when you want to add props/methods on top.
class RecentNonSpamComments < (RecentCommentsQuery + NonSpamCommentsQuery)
  prop :author_id, _Nilable(Integer)
end

# Then per-request, instantiate and use like any Quo class.
RecentNonSpamComments.new(since: 1.day.ago, score: 0.5).results
```

Class composition has real per-call cost (it allocates a new anonymous
class and re-defines properties on it). Treat it as type-definition, not
runtime work — assign to a constant or define a class once at file-load
time.

### 2. Instance composition — `some_instance + other_instance`

When the operands are query **instances**, `+` returns a value-shaped
query that holds both operands. No class is allocated.

```ruby
def list_comments(filters)
  query = RecentCommentsQuery.new(since: filters[:since])
  query += NonSpamCommentsQuery.new(score: filters[:score]) if filters[:score]
  query.results
end
```

Instance composition is cheap. Use it freely inside controllers,
operations, render loops, anywhere you want to combine concrete query
values with their own props.

### Anti-pattern: class composition at the call site

```ruby
# Wrong — allocates a new class on every call to fan props down.
(RecentCommentsQuery + NonSpamCommentsQuery)
  .new(since: 1.day.ago, score: 0.5)
  .results

# Right — instance composition, no class allocation.
(RecentCommentsQuery.new(since: 1.day.ago) +
 NonSpamCommentsQuery.new(score: 0.5))
  .results
```

The wrong form also relies on prop fan-out: the framework guesses that
`since:` belongs to the left class and `score:` to the right. Class
composition at the call site makes that magic *necessary*; instance
composition makes it unnecessary because each leaf gets its own props at
construction.

### Decision guide

| You want to… | Use |
|---|---|
| Define a new query type from existing ones, once | `Q1 + Q2` (class) |
| Combine instances at a call site with specific props | `q1 + q2` (instance) |
| Add props/methods on top of a composition | `class Foo < (Q1 + Q2); ... end` |
| Conditionally add a filter at runtime | `q + maybe_filter` (instance) |
| Wrap a bare AR relation in a hot loop | `Quo::RelationBackedQuery.from(rel)` |

## What instance composition returns

`some_instance + other_instance` returns a **value**, not a class:

- `q1 + q2` where one side is relation-backed →
  `Quo::ComposedRelationBackedQuery`
- both sides collection-backed → `Quo::ComposedCollectionBackedQuery`

Both are real concrete classes with `left`, `right`, `merge_joins` as
typed Literal props. There's a single class per kind; no anonymous
class is allocated per composition call.

These value-form composed queries are themselves `Quo::Query` instances,
so they:

- accept `.results`, `.unwrap`, `.unwrap_unpaginated`, `.to_sql`, etc.
- can be paginated (`.copy(page: 2, page_size: 25)`)
- can have a transformer attached (`.transform { ... }`)
- can themselves be composed further (`(q1 + q2) + q3`)
- can have specs applied (`.order(...)`, `.where(...)`, `.joins(...)`, `.distinct`)
  — the spec is applied to the merged relation at unwrap time.

## `#copy` on a composed instance

`composed.copy(**overrides)` behaves like `copy` on any Quo::Query —
return a new instance with some props overridden. Two kinds of override:

1. Overrides for the composed's own props (`left`, `right`, `merge_joins`,
   `_specification`, `page`, `page_size`) go through the standard Literal
   copy.

2. Overrides for **any other prop** are walked into the operand tree:
   each operand that declares the prop is copied with the new value.
   Composed-as-operand recurses. The composed query exposes one logical
   prop for that name — copying with a new value lands on every leaf
   that owns it.

   ```ruby
   q = Q1.new(score: 0.5) + Q2.new(score: 0.5)
   updated = q.copy(score: 0.9)
   # both operands now have score: 0.9
   ```

3. Unknown prop (declared by no operand) → `ArgumentError`. Same surface
   as a normal `copy(unknown_prop:)` on a leaf.

`#copy` on a composed instance is O(tree size) per fan override —
intended for call-site convenience, not for hot paths.

## Composition behaviour by query type

The `+` operator works across both `RelationBackedQuery` and
`CollectionBackedQuery`. The merge strategy depends on the types being
combined.

### Relation + Relation

Two `RelationBackedQuery` operands → ActiveRecord `merge`.

```ruby
class PublishedPostsQuery < Quo::RelationBackedQuery
  def query
    Post.where("body IS NOT NULL")
  end
end

class PostsByAuthorQuery < Quo::RelationBackedQuery
  prop :author_id, Integer
  def query
    Post.where(author_id: author_id)
  end
end

published = PublishedPostsQuery.new
mine      = PostsByAuthorQuery.new(author_id: 1)
(published + mine).results
# SQL: SELECT "posts".* FROM "posts"
#      WHERE "body" IS NOT NULL AND "posts"."author_id" = 1
```

Behaviours:

- WHERE clauses combine with AND
- Joins are merged
- ORDER clauses combine
- For LIMIT/OFFSET the right operand wins (later overrides earlier)

### Relation + Collection

A `RelationBackedQuery` + a `CollectionBackedQuery` runs the relation,
materialises it to an array, then concatenates with the collection.

```ruby
db_query = PublishedPostsQuery.new
mem      = Quo::CollectionBackedQuery.wrap([extra_post1, extra_post2]).new
(db_query + mem).results.to_a
# Loads all published posts into memory, then appends extras.
```

**Cost note:** the relation is materialised in full — pagination on the
relation side is bypassed by composition. Use sparingly with large
relations.

### Collection + Collection

Two `CollectionBackedQuery` operands → array concatenation.

```ruby
first  = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
second = Quo::CollectionBackedQuery.wrap([4, 5, 6]).new
(first + second).results.to_a  # => [1, 2, 3, 4, 5, 6]
```

## Merge with explicit joins

When composing two Relation queries against different tables, pass `joins:`
so AR knows how to combine them.

```ruby
class PostsQuery < Quo::RelationBackedQuery
  def query
    Post.where("title IS NOT NULL")
  end
end

class AuthorsQuery < Quo::RelationBackedQuery
  prop :verified, _Boolean, default: -> { true }
  def query
    Author.where(verified: verified)  # assumes Author has :verified
  end
end

PostsQuery.new.merge(AuthorsQuery.new, joins: :author).results
# SQL: SELECT "posts".* FROM "posts"
#      INNER JOIN "authors" ON "authors"."id" = "posts"."author_id"
#      WHERE "title" IS NOT NULL AND "authors"."verified" = true
```

Multiple joins chain naturally:

```ruby
posts.merge(authors, joins: :author)
     .merge(comments, joins: :comments)
```

The `joins:` argument accepts anything `ActiveRecord::Relation#joins`
accepts: a Symbol, Hash, or Array of either.

## Composition vs direct chaining

Composition is for **reusable** query fragments. If a query is one-off,
just use AR directly inside a single Quo class.

```ruby
# Composition (good when the parts are reused elsewhere)
class ActiveCommentsQuery < Quo::RelationBackedQuery
  def query; Comment.unread; end
end

class RecentCommentsQuery < Quo::RelationBackedQuery
  prop :since, Time, default: -> { 1.day.ago }
  def query; Comment.where("created_at > ?", since); end
end

(ActiveCommentsQuery.new + RecentCommentsQuery.new(since: 1.hour.ago)).results
```

```ruby
# Direct chaining (better if this is the only place it's used)
class ActiveRecentCommentsQuery < Quo::RelationBackedQuery
  prop :since, Time, default: -> { 1.day.ago }

  def query
    Comment.unread.where("created_at > ?", since)
  end
end
```

**Use composition when:**
- Each fragment is reused in multiple places
- You compose conditionally (some filters only apply sometimes)
- Tests benefit from exercising fragments in isolation

**Use direct chaining when:**
- The query is specific to one call site
- All conditions always apply together
- Performance matters and you want zero composition overhead

## Conditional composition

The instance form is ideal for runtime-conditional filters. Each `+=` is
cheap and only allocates the merged value.

```ruby
def comments_query(filters)
  query = AllCommentsQuery.new
  query += UnreadCommentsQuery.new           if filters[:unread]
  query += NonSpamCommentsQuery.new(score: 0.5) if filters[:hide_spam]
  query += AuthorFilterQuery.new(author_id: filters[:author_id]) if filters[:author_id]
  query
end

comments_query(unread: true, author_id: 42).results
```

For class-level conditional definition (e.g. you build a base type at
load time but want optional layers at construction), prefer giving the
class a single nilable prop and branching inside `#query`:

```ruby
class CommentsQuery < Quo::RelationBackedQuery
  prop :author_id, _Nilable(Integer)
  prop :since, _Nilable(Time)
  prop :hide_spam, _Boolean, default: -> { false }

  def query
    scope = Comment.all
    scope = scope.where(post_id: Post.where(author_id: author_id)) if author_id
    scope = scope.where("created_at > ?", since)                   if since
    scope = scope.where("spam_score < 0.5 OR spam_score IS NULL")  if hide_spam
    scope
  end
end
```

Both styles are valid; pick by where the optionality lives (call site vs.
inside the query type).

## Composition + transformers

Transformers and composition compose in either order. The transformer of
the outer query wins.

```ruby
# Compose first, transform last
base = AllCommentsQuery.new
filtered = base + UnreadCommentsQuery.new
presented = filtered.transform { |c| CommentPresenter.new(c) }
presented.results  # presenters
```

```ruby
# Transform first, compose later — transformer carries through
transformed = AllCommentsQuery.new.transform { |c| CommentPresenter.new(c) }
filtered    = transformed + UnreadCommentsQuery.new
filtered.results  # presenters
```

If both sides have transformers, the *right* one is used for the merged
result. Mixing transformers across composition is rarely what you want;
attach the transformer once, on the outermost query.

## Composition immutability

Compositions never mutate operands. Each `+` returns a fresh value (or a
fresh class, in the class-composition case).

```ruby
base = AllCommentsQuery.new
filter = UnreadCommentsQuery.new
composed = base + filter

base.equal?(composed)    # => false
filter.equal?(composed)  # => false
# base and filter remain independently usable
```

## Testing composed queries

Test fragments individually, then test the composition end-to-end with
representative data.

```ruby
class CommentCompositionTest < ActiveSupport::TestCase
  setup do
    @author = Author.create!(name: "Ada")
    @post = Post.create!(title: "Hi", author: @author)
    @target  = Comment.create!(post: @post, body: "ok",  read: false, spam_score: 0.1)
    @spammy  = Comment.create!(post: @post, body: "buy", read: false, spam_score: 0.9)
    @read    = Comment.create!(post: @post, body: "old", read: true,  spam_score: 0.1)
  end

  test "unread + non_spam returns only unread, non-spammy comments" do
    composed = UnreadCommentsQuery.new + NonSpamCommentsQuery.new(score: 0.5)

    results = composed.results.to_a
    assert_includes results, @target
    refute_includes results, @spammy
    refute_includes results, @read
  end

  test "composition leaves operands intact" do
    base = AllCommentsQuery.new
    filter = UnreadCommentsQuery.new
    _composed = base + filter

    assert base.results.count >= 3
    assert filter.results.count >= 2
  end
end
```

## Performance guidance

- **Prefer Relation + Relation.** All work stays in the database.
- **Avoid Relation + Collection on hot paths.** It materialises the
  full relation in memory.
- **Hoist class compositions to constants.** Don't use class composition
  per-request; use instance composition there.
- **Don't `wrap(rel).new` on hot paths.** Like class composition, `wrap`
  allocates a new class. Hoist to a constant if you call it more than
  once. (See `references/QUERY_TYPES.md` on `wrap` for detail.)
- **Profile if in doubt.** A 10-line Quo composition can hide a
  surprising amount of class allocation if used incorrectly. The
  class/instance distinction is the lever to pull — instance
  composition allocates no new classes per call.
