# Query Types Reference

> **Targets Quo `~> 2.0`.**

Quo provides two primary query types:

- **`Quo::RelationBackedQuery`** — wraps an `ActiveRecord::Relation`
- **`Quo::CollectionBackedQuery`** — wraps any `Enumerable`

Both share the same outer surface: typed properties via `prop`,
pagination, composition with `+`, transformers, and a `Quo::Results`
return value from `#results`.

## RelationBackedQuery

### When to use

For database queries — anything you'd write in ActiveRecord. This is the
common case.

### Structure

Subclass and implement `#query`. The method must return an
`ActiveRecord::Relation` (not a materialised array).

```ruby
class CommentsByAuthorQuery < Quo::RelationBackedQuery
  prop :author_id, Integer
  prop :since, _Nilable(Time)
  prop :limit, Integer, default: -> { 50 }

  def query
    scope = Comment
      .joins(:post)
      .where(posts: {author_id: author_id})
      .order(created_at: :desc)
    scope = scope.where("comments.created_at > ?", since) if since
    scope.limit(limit)
  end
end

query = CommentsByAuthorQuery.new(author_id: 1, since: 1.day.ago, page: 1, page_size: 25)
results = query.results
results.each { |comment| puts comment.body }
```

### `#query` must return a Relation

```ruby
# Right
def query
  Comment.where(read: false).order(:created_at)
end

# Wrong — array, not relation
def query
  Comment.where(read: false).to_a
end
```

`#query` is allowed to return another `Quo::Query` instance — Quo will
unwrap it. That makes it natural to compose inside a query class:

```ruby
class PopularRecentCommentsQuery < Quo::RelationBackedQuery
  prop :since, Time, default: -> { 1.day.ago }

  def query
    UnreadCommentsQuery.new + RecentCommentsQuery.new(since: since)
  end
end
```

### Lazy evaluation

Construction never hits the database. The query runs when you ask for
results.

```ruby
query = CommentsByAuthorQuery.new(author_id: 1)
# No SQL yet.

query.results.each { |c| ... }
# SQL runs here.
```

### Utility methods

```ruby
query = CommentsByAuthorQuery.new(author_id: 1)

query.to_sql              # => SQL string
query.unwrap_unpaginated  # => ActiveRecord::Relation (no LIMIT/OFFSET)
query.unwrap              # => ActiveRecord::Relation (with paging applied if any)

query.relation?           # => true
query.collection?         # => false
```

## CollectionBackedQuery

### When to use

For in-memory enumerables — cached data, API responses, pre-loaded
arrays. Avoid for large datasets you'd be loading from the database
anyway; use `RelationBackedQuery` and let the database do the work.

### Structure

Subclass and implement `#collection`. The method must return an
`Enumerable` (typically an Array).

```ruby
class TopRatedCommentsQuery < Quo::CollectionBackedQuery
  prop :comments, _Array(Comment)
  prop :max_spam_score, Float, default: -> { 0.5 }

  def collection
    comments
      .select { |c| c.spam_score && c.spam_score < max_spam_score }
      .sort_by { |c| c.spam_score || 0 }
  end
end

query = TopRatedCommentsQuery.new(comments: Comment.all.to_a, max_spam_score: 0.3)
query.results.each { |c| puts c.body }
```

### `#collection` must return Enumerable

```ruby
# Right — Array
def collection
  items.select { |i| i.active? }
end

# Right — Set
def collection
  Set.new(items)
end

# Wrong — single item
def collection
  items.first
end
```

### Pagination happens in memory

```ruby
query = TopRatedCommentsQuery.new(comments: huge_array, page: 2, page_size: 10)
query.results
# All `huge_array` lives in memory; pagination slices it.
```

For large data sets, prefer a `RelationBackedQuery` so the database can
limit before returning rows.

### Utility methods

```ruby
query = TopRatedCommentsQuery.new(comments: comments)

query.unwrap_unpaginated  # => Array (full)
query.unwrap              # => Array (paginated slice if paged?)

query.relation?           # => false
query.collection?         # => true
```

## Converting between types

`#to_collection` materialises a `RelationBackedQuery` into a
`CollectionBackedQuery`. Useful for caching the materialised array.

```ruby
relation_query = CommentsByAuthorQuery.new(author_id: 1)
collection_query = relation_query.to_collection

collection_query.relation?    # => false
collection_query.collection?  # => true
```

A common cache pattern:

```ruby
class CachedRecentCommentsQuery < Quo::CollectionBackedQuery
  prop :author_id, Integer
  prop :ttl, ActiveSupport::Duration, default: -> { 5.minutes }

  def collection
    Rails.cache.fetch("comments:author:#{author_id}", expires_in: ttl) do
      CommentsByAuthorQuery.new(author_id: author_id).results.to_a
    end
  end
end
```

## Property types reference

Quo uses [Literal](https://github.com/joeldrapper/literal) for type
validation. Literal's helper methods on Quo classes are prefixed with
underscore (e.g. `_Nilable`, `_Array`, `_Union`, `_Boolean`).

### Primitives

```ruby
prop :name, String
prop :count, Integer
prop :price, Float
prop :enabled, _Boolean    # NB: _Boolean, not Boolean
prop :data, Hash
prop :items, Array
```

### Custom classes

```ruby
prop :author, Author
prop :post, Post
prop :comment, Comment
```

### Arrays

```ruby
prop :tags, _Array(String)
prop :ids, _Array(Integer)
prop :authors, _Array(Author)
```

### Nilable

```ruby
prop :since, _Nilable(Time)
prop :status, _Nilable(String)
```

### Unions

```ruby
prop :id_or_slug, _Union(String, Integer)
```

### Defaults

```ruby
# Use a lambda for any non-frozen default — avoids shared mutable state.
prop :tags, _Array(String), default: -> { [] }
prop :since, Time, default: -> { 1.day.ago }
prop :page_size, Integer, default: -> { 20 }

# Frozen literals are also OK:
prop :status, String, default: "pending".freeze
```

### Boolean caveat

Use `_Boolean` (Literal helper), not bare `Boolean`:

```ruby
prop :enabled, _Boolean             # right
prop :enabled, Boolean              # wrong — there's no top-level Boolean class
```

## Property validation

Properties validate at construction. Wrong types and missing required
values raise `Literal::TypeError`.

```ruby
class StrictQuery < Quo::RelationBackedQuery
  prop :author_id, Integer
  prop :limit, Integer, default: -> { 50 }
end

StrictQuery.new(author_id: 1)              # OK
StrictQuery.new(author_id: "1")            # raises — wrong type
StrictQuery.new(limit: 10)                 # raises — missing :author_id
```

## Method requirements summary

| Type | Implement | Returns |
|---|---|---|
| `Quo::RelationBackedQuery` | `#query` | `ActiveRecord::Relation` (or another `Quo::Query`) |
| `Quo::CollectionBackedQuery` | `#collection` | `Enumerable` |

## Choosing between types

| Use case | Pick |
|---|---|
| Database query that pages and filters | `RelationBackedQuery` |
| Need raw SQL access (`#to_sql`) | `RelationBackedQuery` |
| Cached array, API response, in-memory filter | `CollectionBackedQuery` |
| Caching the result of a relation query | `RelationBackedQuery` → `to_collection` |
| Composing with `.where`/`.joins`/`.order` | `RelationBackedQuery` |
