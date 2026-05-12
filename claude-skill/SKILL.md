---
name: quo
description: Build composable, type-safe query objects using the Quo gem. Use when creating ActiveRecord or collection queries, composing queries, paginating, or transforming results.
---

# Quo Query Objects

> **Targets Quo `~> 2.0`.** This skill matches the API of the 2.0 line.
> If you upgrade Quo, re-run the install generator to refresh the skill:
> `bin/rails generate quo:install --force`.
>
> If you're upgrading from 1.x, see `UPGRADING.md` in the gem for the
> two intentional behavioural changes (prop fan-out semantics and
> pagination inheritance).

## Overview

Quo is a Ruby gem that encapsulates database and collection queries into
reusable, composable, testable objects. It provides type-safe properties
(via the [Literal](https://github.com/joeldrapper/literal) gem), built-in
pagination, and a fluent API similar to ActiveRecord.

### Core components

1. **Query objects** — define and configure queries with typed properties
2. **Results objects** — execute queries and provide access to paginated data
3. **Composition** — combine queries using `+` (or `compose` / `merge`)

### When to use Quo

**Use Quo for:**
- Complex queries that are reused across the app
- Queries with configurable, typed parameters
- Queries that need pagination
- Composing reusable query fragments
- Encapsulating collection filtering logic

**Avoid Quo for:**
- Simple one-off queries — use ActiveRecord directly
- Queries with no parameters worth typing
- Logic that lives in exactly one place

**Anti-pattern:** a Quo class whose body is a single `where(...)`. That's
just AR with extra ceremony. If a filter is one line and has no parameters
worth typing, keep it inline (`Comment.where(read: true)`) rather than
wrapping in a Quo class.

## Composition: class-level vs instance-level

This is the most important distinction in Quo and the most commonly misused.
There are **two** composition modes. They look identical (`+`) but they do
different work and have very different costs. Pick deliberately.

### Class composition — defining a new named query type

Use this when you want to **define a new, reusable query type** in terms
of existing ones. It runs once at code-load time. `+` between two classes
returns a new Class.

```ruby
# As a constant — the composition runs once when the file is loaded.
RecentNonSpamComments = RecentCommentsQuery + NonSpamCommentsQuery

# As a superclass — when you want to add props or methods on top.
class RecentNonSpamComments < (RecentCommentsQuery + NonSpamCommentsQuery)
  prop :author_id, _Nilable(Integer)
end

# Then per-request, you instantiate it like any Quo class.
RecentNonSpamComments.new(since: 1.day.ago, score: 0.5).results
```

### Instance composition — combining queries at a call site

Use this when you want to **merge concrete query instances** per request,
each with its own props. `+` between two instances returns a value-shaped
query — cheap to do inside a hot path, render loop, or controller.

```ruby
def call
  (RecentCommentsQuery.new(since: 1.day.ago) +
   NonSpamCommentsQuery.new(score: 0.5))
    .results
end
```

### Anti-pattern: class composition at the call site

Don't reach for class composition when you actually want instance
composition. This pattern looks ergonomic but allocates a fresh anonymous
class on every call:

```ruby
# Wrong — allocates a new class every request, just to instantiate it once.
(RecentCommentsQuery + NonSpamCommentsQuery)
  .new(since: 1.day.ago, score: 0.5)
  .results

# Right — instance composition, no class allocation.
(RecentCommentsQuery.new(since: 1.day.ago) +
 NonSpamCommentsQuery.new(score: 0.5))
  .results
```

The "wrong" version also relies on prop fan-out: the framework figures out
that `since:` belongs to the left query and `score:` to the right.
Class-level call-site composition makes that magic *necessary*; instance
composition makes it unnecessary because each leaf gets its own props at
construction.

### Quick decision guide

| You want to… | Use |
|---|---|
| Define a new query type from existing ones, once | `Q1 + Q2` (class) |
| Combine instances at a call site with specific props | `q1 + q2` (instance) |
| Add props/methods on top of a composition | `class Foo < (Q1 + Q2); ... end` |
| Conditionally add a filter at runtime | `q + maybe_filter` (instance) |

For more depth: see `references/COMPOSITION.md`.

## Quick reference: query types

### RelationBackedQuery (ActiveRecord queries)

```ruby
class RecentCommentsQuery < Quo::RelationBackedQuery
  prop :since, Time, default: -> { 1.week.ago }
  prop :status, _Nilable(String)

  def query
    scope = Comment.where("created_at > ?", since).order(created_at: :desc)
    scope = scope.where(status: status) if status
    scope
  end
end

# Usage
query = RecentCommentsQuery.new(since: 7.days.ago, page: 1, page_size: 25)
results = query.results

results.each { |comment| puts comment.body }
results.count        # total across all pages
results.page_count   # rows in current page
```

### CollectionBackedQuery (in-memory collections)

```ruby
class TopRatedCommentsQuery < Quo::CollectionBackedQuery
  prop :comments, _Array(Comment)
  prop :min_score, Float, default: -> { 0.5 }

  def collection
    comments.select { |c| c.spam_score && c.spam_score < min_score }
  end
end

query = TopRatedCommentsQuery.new(comments: Comment.all.to_a, min_score: 0.3)
filtered = query.results
```

**Detail:** [references/QUERY_TYPES.md](references/QUERY_TYPES.md)

## Quick reference: type-safe properties

Quo uses Literal for runtime type validation. Declare props with `prop`:

```ruby
class CommentsByAuthorQuery < Quo::RelationBackedQuery
  # Required
  prop :author_id, Integer

  # Optional with default
  prop :limit, Integer, default: -> { 50 }
  prop :include_unread, _Boolean, default: -> { true }

  # Nilable (allows nil explicitly)
  prop :since, _Nilable(Time)

  # Arrays / unions
  prop :tags, _Array(String), default: -> { [] }
  prop :id_or_slug, _Union(String, Integer)

  def query
    scope = Comment.joins(:post).where(posts: {author_id: author_id})
    scope = scope.where("comments.created_at > ?", since) if since
    scope = scope.where(read: false) unless include_unread
    scope = scope.where(tag: tags) if tags.any?
    scope.limit(limit)
  end
end
```

Common patterns:

```ruby
prop :name, String                  # primitive
prop :enabled, _Boolean             # boolean
prop :tags, _Array(String)          # typed array
prop :since, _Nilable(Time)         # nilable
prop :status, _Union(String, Symbol) # union
prop :author, Author                # AR model class
```

## Quick reference: pagination

```ruby
# Page 1 of 25 per page
query = CommentsByAuthorQuery.new(author_id: 1, page: 1, page_size: 25)
results = query.results

# Navigation — return new query objects, don't mutate
next_query = query.next_page_query
prev_query = query.previous_page_query

# Counts
results.count        # total across all pages
results.page_count   # rows in current page

# Inspect
query.paged?         # true

# All rows, no pagination
query.unwrap_unpaginated.to_a
```

**Detail:** [references/PAGINATION.md](references/PAGINATION.md)

## Quick reference: result transformations

Attach a transformer to wrap each row as it comes out of the query:

```ruby
query = CommentsByAuthorQuery.new(author_id: 1)
  .transform { |comment| CommentPresenter.new(comment) }

query.results.each do |presenter|
  puts presenter.formatted_body
end

# Transformers apply to every Enumerable method
query.results.map(&:formatted_body)
query.results.group_by(&:status)
```

Pass extra context via the surrounding scope:

```ruby
viewer = current_user
query = CommentsByAuthorQuery.new(author_id: 1)
  .transform { |comment| CommentPresenter.new(comment, viewer: viewer) }
```

**Detail:** [references/TRANSFORMERS.md](references/TRANSFORMERS.md)

## Quick reference: `wrap` vs `from`

Two APIs for adopting a bare relation or enumerable into Quo, with
different shapes and costs. Pick by use case:

### `.from` — value form (use at call sites)

`Quo::RelationBackedQuery.from(rel)` returns a **Quo::Query instance**
that wraps the relation. No class allocation per call. Use this when
you want a Quo query value at a call site (operations, controllers,
hot loops):

```ruby
# In an operation / controller
Quo::RelationBackedQuery.from(Comment.where(read: false)).results

# Composes naturally with v2 instance composition
(Quo::RelationBackedQuery.from(rel) + UnreadCommentsQuery.new).results

# Same for collections
Quo::CollectionBackedQuery.from(cached_array).results
```

### `wrap` — class form (use for type definition)

`Quo::RelationBackedQuery.wrap(...)` returns a **Class**. Useful when
you want to define a named query type once at code-load time, possibly
parameterised via the block form:

```ruby
# As a constant — evaluated once when the file loads.
ActiveCommentsQuery = Quo::RelationBackedQuery.wrap(Comment.where(read: false))
ActiveCommentsQuery.new.results

# Block form with typed props — the block captures over `self` so props
# are accessible.
RecentCommentsForAuthor = Quo::RelationBackedQuery.wrap(props: {author_id: Integer}) do
  Comment.joins(:post).where(posts: {author_id: author_id})
end
RecentCommentsForAuthor.new(author_id: 1).results

# Wrap a cached value as a collection query
CachedAuthors = Quo::CollectionBackedQuery.wrap do
  Rails.cache.fetch("all_authors") { Author.all.to_a }
end
```

> **Anti-pattern:** `Quo::RelationBackedQuery.wrap(rel).new` at a call
> site. `wrap` allocates a new anonymous class on every call only to
> instantiate it once and discard the class — the same waste pattern
> v2 removed from instance composition. Use `.from(rel)` for the
> value form, or hoist the `wrap(...)` to a constant if you want the
> class form.

## Quick reference: type conversion

```ruby
# RelationBackedQuery → CollectionBackedQuery
relation_query = CommentsByAuthorQuery.new(author_id: 1)
collection_query = relation_query.to_collection

collection_query.collection?  # => true
collection_query.relation?    # => false
```

## Quick reference: utility methods

```ruby
query = CommentsByAuthorQuery.new(author_id: 1, page: 1)

query.relation?            # backed by an AR relation?
query.collection?          # backed by a collection?
query.paged?               # pagination enabled?
query.transform?           # transformer attached?
query.unwrap               # paginated AR::Relation
query.unwrap_unpaginated   # full unpaginated AR::Relation
query.to_sql               # SQL string (RelationBackedQuery only)

results = query.results
results.exists?            # any rows?
results.empty?             # zero rows?
results.count              # total across all pages
results.page_count         # rows in current page
results.first / .last
results.map { ... }
results.group_by { ... }
```

## Common patterns

### Conditional filter composition

```ruby
def list_comments(filters = {})
  query = CommentsByAuthorQuery.new(author_id: filters[:author_id])
  query += UnreadCommentsQuery.new            if filters[:unread]
  query += NonSpamCommentsQuery.new(score: 0.5) if filters[:hide_spam]
  query.results
end
```

(Each `+` here is **instance composition** — cheap, value-level.)

### Presenters via transformers in a controller

```ruby
class CommentsController < ApplicationController
  def index
    query = CommentsByAuthorQuery
      .new(author_id: params[:author_id], page: params[:page])
      .transform { |c| CommentPresenter.new(c, viewer: current_user) }

    render :index, locals: {comments: query.results, paginator: query}
  end
end
```

### Testing a query object

```ruby
class CommentsByAuthorQueryTest < ActiveSupport::TestCase
  setup do
    @author = Author.create!(name: "Ada")
    @post = Post.create!(title: "Hi", author: @author)
    @target = Comment.create!(post: @post, body: "ok", read: false)
    Comment.create!(post: @post, body: "spam", read: true)
  end

  test "returns comments for the given author" do
    results = CommentsByAuthorQuery.new(author_id: @author.id).results
    assert_includes results, @target
  end

  test "pagination returns page-sized chunks" do
    20.times { |i| Comment.create!(post: @post, body: "x#{i}") }

    query = CommentsByAuthorQuery.new(author_id: @author.id, page: 1, page_size: 10)
    assert_equal 10, query.results.page_count

    next_page = query.next_page_query
    assert_equal 2, next_page.page
  end
end
```

## Reference files

| File | Read when you need… |
|---|---|
| [QUERY_TYPES.md](references/QUERY_TYPES.md) | Detail on RelationBackedQuery vs CollectionBackedQuery, conversion, internals |
| [COMPOSITION.md](references/COMPOSITION.md) | Composition modes, merge strategies, joins, conditional building |
| [PAGINATION.md](references/PAGINATION.md) | Page navigation, counts, unpaginated access |
| [TRANSFORMERS.md](references/TRANSFORMERS.md) | Result transformation, presenter patterns, scope of context capture |
| [API_REFERENCE.md](references/API_REFERENCE.md) | Method-by-method reference for queries and results |

## External resources

- Documentation site: <https://quo-gem.diaconou.com/>
- Source: <https://github.com/stevegeek/quo>
- Literal (type system): <https://github.com/joeldrapper/literal>
