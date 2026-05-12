# Pagination Reference

> **Targets Quo `~> 2.0`.**

Quo provides built-in pagination for both `RelationBackedQuery` and
`CollectionBackedQuery`. Pagination is consistent across query types and
integrates with composition and transformers without surprise.

## Page parameters

Every Quo query accepts two pagination kwargs:

```ruby
query = CommentsByAuthorQuery.new(
  author_id: 1,
  page: 2,        # 1-indexed
  page_size: 25
)
results = query.results
```

### Defaults

If you don't pass `page` / `page_size`, the defaults are applied:

```ruby
query = CommentsByAuthorQuery.new(author_id: 1)
query.page_size  # => 20 (or whatever Quo.default_page_size is)
query.paged?     # => false (no page set)
```

You can configure the default page size globally:

```ruby
# config/initializers/quo.rb
Quo.default_page_size = 25
```

There's also a hard cap (`Quo.max_page_size`, default 200) that protects
against runaway page sizes from untrusted input.

### Checking pagination status

```ruby
query = CommentsByAuthorQuery.new(author_id: 1, page: 1)
query.paged?  # => true

unpaginated = CommentsByAuthorQuery.new(author_id: 1, page: nil)
unpaginated.paged?  # => false
```

## Working with results

### Counts

```ruby
query = CommentsByAuthorQuery.new(author_id: 1, page: 2, page_size: 25)
results = query.results

results.count       # total across all pages
results.page_count  # rows in current page
```

### Existence

```ruby
results.empty?
results.exists?
```

### Iteration

Standard `Enumerable` works:

```ruby
results.each { |c| ... }
results.map(&:body)
results.select { |c| c.read? }
results.first
results.last
```

## Page navigation

`#next_page_query` / `#previous_page_query` return new query objects;
they don't mutate.

```ruby
query = CommentsByAuthorQuery.new(author_id: 1, page: 1, page_size: 25)

next_query = query.next_page_query
next_query.page  # => 2

prev_query = query.copy(page: 5).previous_page_query
prev_query.page  # => 4
```

### Jumping to a specific page

`#copy` lets you change any prop, including `page`:

```ruby
query = CommentsByAuthorQuery.new(author_id: 1, page: 1, page_size: 25)
page_5 = query.copy(page: 5)
```

### Offset

Calculated from page and page_size:

```ruby
query = CommentsByAuthorQuery.new(author_id: 1, page: 3, page_size: 25)
query.offset  # => 50  (page 3 starts at row 51, 0-indexed offset 50)
```

### Total page count

There's no built-in `total_pages` — derive it from `results.count`:

```ruby
results = query.results
total_pages = (results.count.to_f / query.page_size).ceil
```

### "Has next page?"

```ruby
def has_next_page?(query)
  query.results.count > query.page * query.page_size
end

def has_previous_page?(query)
  query.page > 1
end
```

## Unpaginated access

### Disable pagination explicitly

```ruby
query = CommentsByAuthorQuery.new(author_id: 1, page: nil)
query.paged?  # => false
all = query.results.to_a
```

### Unwrap

`#unwrap` returns the underlying relation/collection with paging applied
if `paged?`. `#unwrap_unpaginated` gives you the full thing regardless.

```ruby
query = CommentsByAuthorQuery.new(author_id: 1, page: 2, page_size: 25)

paginated_rel    = query.unwrap                # AR::Relation w/ LIMIT 25 OFFSET 25
unpaginated_rel  = query.unwrap_unpaginated    # AR::Relation, no LIMIT/OFFSET
```

For collections you get the array slice or the full array.

### Use cases for unpaginated

- Exporting all rows to CSV
- Aggregating across all rows
- Caching the full materialised result

```ruby
query = CommentsByAuthorQuery.new(author_id: 1)

CSV.generate do |csv|
  query.unwrap_unpaginated.find_each(batch_size: 1_000) do |comment|
    csv << [comment.id, comment.body]
  end
end
```

For very large result sets, use `find_each` (or `find_in_batches`)
on the AR relation rather than materialising.

## Pagination + composition

### Composed queries inherit pagination

```ruby
base = CommentsByAuthorQuery.new(author_id: 1, page: 2, page_size: 25)
filter = UnreadCommentsQuery.new

composed = base + filter
composed.page       # => 2
composed.page_size  # => 25
composed.paged?     # => true
```

### Setting pagination after composition

```ruby
composed = CommentsByAuthorQuery.new(author_id: 1) + UnreadCommentsQuery.new
paginated = composed.copy(page: 1, page_size: 50)
paginated.results
```

### Different page sizes in operands

When operands disagree, the leftmost wins:

```ruby
left  = CommentsByAuthorQuery.new(author_id: 1, page_size: 10)
right = UnreadCommentsQuery.new(page_size: 20)

(left + right).page_size  # => 10
```

In practice, set pagination on the outermost composition, not on
operands.

## Pagination + transformers

Transformers carry through pagination unchanged.

```ruby
query = CommentsByAuthorQuery.new(author_id: 1, page: 1, page_size: 25)
  .transform { |c| CommentPresenter.new(c) }

results = query.results
results.first         # => CommentPresenter
results.page_count    # => 25
results.count         # => total across all pages

next_results = query.next_page_query.results
next_results.first    # => CommentPresenter (transformer preserved)
```

## Controller patterns

### Basic pagination

```ruby
class CommentsController < ApplicationController
  def index
    @query = CommentsByAuthorQuery.new(
      author_id: params[:author_id],
      page: params[:page] || 1,
      page_size: 25
    )
    @comments = @query.results
  end
end
```

### Caps on user-supplied page size

```ruby
def safe_page_size
  raw = params[:per_page]&.to_i || 20
  [raw, 100].min
end
```

(Quo enforces its own `max_page_size` cap globally — this gives you a
per-endpoint cap on top.)

### Pagination metadata for an API response

```ruby
def index
  query = CommentsByAuthorQuery.new(
    author_id: current_user.id,
    page: params[:page] || 1,
    page_size: safe_page_size
  )
  results = query.results

  render json: {
    data: results.map { |c| {id: c.id, body: c.body} },
    meta: {
      current_page: query.page,
      per_page: query.page_size,
      total_count: results.count,
      total_pages: (results.count.to_f / query.page_size).ceil,
      has_next: results.count > query.page * query.page_size,
      has_prev: query.page > 1,
    },
  }
end
```

## Performance notes

### RelationBackedQuery is efficient

```ruby
query = CommentsByAuthorQuery.new(author_id: 1, page: 1, page_size: 25)
query.results
# SELECT comments.* FROM comments JOIN posts ... LIMIT 25 OFFSET 0
# Only 25 rows materialised.
```

A separate count query is issued when you call `results.count`.

### CollectionBackedQuery loads everything

In-memory pagination slices an already-fully-materialised collection.
That's appropriate for small/cached data, not for large datasets.

### Avoid N+1 in a paginated query

Eager-load associations the page will use:

```ruby
class CommentsByAuthorQuery < Quo::RelationBackedQuery
  prop :author_id, Integer

  def query
    Comment
      .joins(:post)
      .includes(:post)                  # avoid N+1 on `comment.post`
      .where(posts: {author_id: author_id})
  end
end
```

### Batch processing

For full-dataset processing, skip pagination and use AR's batch API on
the unpaginated relation:

```ruby
CommentsByAuthorQuery.new(author_id: 1)
  .unwrap_unpaginated
  .find_each(batch_size: 1_000) do |comment|
    ProcessCommentJob.perform_later(comment.id)
  end
```

## Testing pagination

```ruby
class CommentsByAuthorQueryPaginationTest < ActiveSupport::TestCase
  setup do
    @author = Author.create!(name: "Ada")
    @post = Post.create!(title: "Hi", author: @author)
    75.times { |i| Comment.create!(post: @post, body: "c#{i}") }
  end

  test "paginates correctly" do
    query = CommentsByAuthorQuery.new(author_id: @author.id, page: 1, page_size: 25)
    results = query.results

    assert_equal 25, results.page_count
    assert_equal 75, results.count
    assert query.paged?
  end

  test "next_page_query returns next page" do
    query = CommentsByAuthorQuery.new(author_id: @author.id, page: 1, page_size: 25)
    assert_equal 2, query.next_page_query.page
  end

  test "previous_page_query returns previous page" do
    query = CommentsByAuthorQuery.new(author_id: @author.id, page: 3, page_size: 25)
    assert_equal 2, query.previous_page_query.page
  end

  test "unpaginated returns everything" do
    query = CommentsByAuthorQuery.new(author_id: @author.id, page: nil)
    results = query.results

    assert_equal 75, results.count
    assert_equal 75, results.page_count
    refute query.paged?
  end
end
```
