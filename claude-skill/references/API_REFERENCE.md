# API Reference

> **Targets Quo `~> 1.0`.**

## Query class methods

### `.wrap(query = nil, props: {}, &block)`

Create a query class without defining a full subclass.

```ruby
# Wrap a relation
RecentComments = Quo::RelationBackedQuery.wrap(Comment.where("created_at > ?", 1.day.ago))
RecentComments.new.results

# Wrap with typed props inside a block
CommentsByAuthor = Quo::RelationBackedQuery.wrap(props: {author_id: Integer}) do
  Comment.joins(:post).where(posts: {author_id: author_id})
end
CommentsByAuthor.new(author_id: 1).results

# Wrap a collection
CachedAuthors = Quo::CollectionBackedQuery.wrap do
  Rails.cache.fetch("authors") { Author.all.to_a }
end
```

**Returns:** Query class.

**Performance note:** `wrap` allocates a new class on each call. Treat it
as type-definition: assign the result to a constant. Don't call
`Quo::RelationBackedQuery.wrap(rel).new` inside a method that runs many
times per request.

---

### `.compose(right, joins: nil)` (alias `+`)

Compose two query classes. Returns a new class that, when instantiated,
runs both underlying queries merged together.

```ruby
ComposedClass = ActiveCommentsQuery.compose(NonSpamCommentsQuery)
# Equivalent to: ComposedClass = ActiveCommentsQuery + NonSpamCommentsQuery
ComposedClass.new(score: 0.5).results
```

**Parameters:**
- `right` — Query class to compose with
- `joins:` — optional join argument (Symbol/Hash/Array) for the AR merge

**Returns:** Composed query class.

See `references/COMPOSITION.md` for class-vs-instance composition guidance.

---

## Query instance methods

### `#initialize(**props)`

```ruby
query = CommentsByAuthorQuery.new(
  author_id: 1,
  since: 1.day.ago,
  page: 1,
  page_size: 25
)
```

**Parameters:** keyword arguments matching the query's `prop` declarations,
plus `page` and `page_size`.

**Raises:** `Literal::TypeError` on type mismatch or missing required props.

---

### `#query` (RelationBackedQuery — must implement)

Return an `ActiveRecord::Relation` (or another `Quo::Query`).

```ruby
def query
  Comment.where(read: false).order(:created_at)
end
```

---

### `#collection` (CollectionBackedQuery — must implement)

Return an `Enumerable`.

```ruby
def collection
  items.select { |i| i.score > 0.5 }
end
```

---

### `#results`

Run the query and return a `Quo::Results`.

```ruby
results = query.results
results.each { |row| ... }
results.count
```

**Returns:** `Quo::Results`.

---

### `#copy(**overrides)`

Return a new query instance with overridden props. Doesn't mutate `self`.

```ruby
page_2 = query.copy(page: 2)
larger = query.copy(page_size: 100)
```

**Returns:** new query instance of the same class.

---

### `#merge(right, joins: nil)` (alias `+` for instances)

Compose two query instances. Returns a value-shaped query, no class
allocation.

```ruby
left  = CommentsByAuthorQuery.new(author_id: 1)
right = UnreadCommentsQuery.new

merged = left.merge(right)
# Or: merged = left + right
```

**Parameters:**
- `right` — query instance, AR relation, or enumerable
- `joins:` — optional join argument (Symbol/Hash/Array) for the AR merge

**Returns:** new composed query instance.

---

### `#transform(&block)`

Attach a transformer that runs on each row of `results`.

```ruby
query = CommentsByAuthorQuery.new(author_id: 1)
  .transform { |c| CommentPresenter.new(c) }

query.results.first  # => CommentPresenter
```

**Returns:** new query instance with the transformer attached.

---

### `#next_page_query` / `#previous_page_query`

Return new query instances at adjacent pages.

```ruby
query = CommentsByAuthorQuery.new(author_id: 1, page: 1, page_size: 25)
query.next_page_query.page      # => 2
query.copy(page: 5).previous_page_query.page  # => 4
```

---

### `#offset`

Computed: `(page - 1) * page_size`.

```ruby
query = CommentsByAuthorQuery.new(author_id: 1, page: 3, page_size: 25)
query.offset  # => 50
```

---

### `#unwrap` / `#unwrap_unpaginated`

```ruby
query = CommentsByAuthorQuery.new(author_id: 1, page: 2, page_size: 25)

query.unwrap              # AR::Relation w/ LIMIT 25 OFFSET 25
query.unwrap_unpaginated  # AR::Relation, no LIMIT/OFFSET
```

For `CollectionBackedQuery`, `#unwrap` returns a paginated array slice
and `#unwrap_unpaginated` returns the full enumerable.

---

### `#to_sql` (RelationBackedQuery only)

```ruby
CommentsByAuthorQuery.new(author_id: 1).to_sql
# => "SELECT ... FROM comments INNER JOIN posts ..."
```

---

### `#to_collection`

Materialise a `RelationBackedQuery` into a `CollectionBackedQuery`.

```ruby
relation_q = CommentsByAuthorQuery.new(author_id: 1)
collection_q = relation_q.to_collection
collection_q.collection?  # => true
```

---

### Predicates

```ruby
query.relation?     # backed by AR relation?
query.collection?   # backed by enumerable?
query.paged?        # pagination enabled?
query.transform?    # transformer attached?
```

---

### Property accessors

`#page`, `#page_size`, plus accessors for any `prop` you declared.

```ruby
query = CommentsByAuthorQuery.new(author_id: 1, page: 3, page_size: 50)
query.page        # => 3
query.page_size   # => 50
query.author_id   # => 1
```

---

## Quo::Results methods

### Counts

| Method | Returns |
|---|---|
| `#count` | total rows (across all pages) |
| `#page_count` | rows in the current page |
| `#empty?` | true when there are no rows |
| `#exists?` | true when there's at least one row |

### Enumerable

`Quo::Results` includes `Enumerable` and delegates `#each`, `#map`,
`#select`, `#reject`, `#first`, `#last`, `#find`, `#group_by`, `#to_a`.
If a transformer is set, each yielded row passes through it.

```ruby
results.each { |c| ... }
results.map(&:body)
results.select { |c| c.read? }
results.group_by(&:read)
results.to_a
```

### `#transform?`

Boolean — was a transformer attached to the query?

---

## Property type reference

Quo uses [Literal](https://github.com/joeldrapper/literal). Its helper
methods on Quo classes are prefixed with underscore.

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
```

### Arrays / Nilable / Unions

```ruby
prop :tags, _Array(String)
prop :ids, _Array(Integer)
prop :since, _Nilable(Time)
prop :id_or_slug, _Union(String, Integer)
```

### Defaults

Use a lambda for any non-frozen default to avoid shared mutable state.

```ruby
prop :tags, _Array(String), default: -> { [] }
prop :since, Time, default: -> { 1.day.ago }
prop :page_size, Integer, default: -> { 20 }
prop :status, String, default: "pending".freeze
```

---

## Configuration

```ruby
# config/initializers/quo.rb
Quo.default_page_size = 25
Quo.max_page_size = 200
Quo.relation_backed_query_base_class_name = "ApplicationRelationQuery"
Quo.collection_backed_query_base_class_name = "ApplicationCollectionQuery"
```

The base class options let you set application-level defaults (e.g. a
`hello` method shared by every relation-backed query) by subclassing the
base classes once and pointing Quo at the subclass.

---

## Errors

### `Literal::TypeError`

Raised at `#initialize` when a prop value violates its declared type.

```ruby
class StrictQuery < Quo::RelationBackedQuery
  prop :author_id, Integer
end

StrictQuery.new(author_id: "1")
# => Literal::TypeError: author_id is "1", expected Integer

StrictQuery.new
# => Literal::TypeError: author_id is nil, expected Integer
```

### `ArgumentError`

Raised by `Quo::Composing.composer` / `Quo::Composing.merge_instances`
if the operands aren't a valid combination.

---

## End-to-end example

```ruby
class CommentsByAuthorQuery < Quo::RelationBackedQuery
  prop :author_id, Integer
  prop :since, _Nilable(Time)
  prop :include_read, _Boolean, default: -> { true }

  def query
    scope = Comment
      .joins(:post)
      .where(posts: {author_id: author_id})
      .order(created_at: :desc)
    scope = scope.where("comments.created_at > ?", since) if since
    scope = scope.where(read: false) unless include_read
    scope
  end
end

# In a controller
def index
  query = CommentsByAuthorQuery
    .new(
      author_id: params[:author_id].to_i,
      since: params[:since] && Time.zone.parse(params[:since]),
      include_read: params[:include_read] != "false",
      page: params[:page] || 1,
      page_size: 25,
    )
    .transform { |c| CommentPresenter.new(c, viewer: current_user) }

  render :index, locals: {comments: query.results, paginator: query}
end
```
