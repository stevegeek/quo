# Result Transformers Reference

> **Targets Quo `~> 2.0`.**

Transformers apply a function to each row as it comes out of a query.
Common uses: wrapping rows in presenter/serializer objects, converting
to DTOs, or applying view-specific logic without modifying the
underlying query.

## Attaching a transformer

`#transform` takes a block and returns a new query that wraps each row
through the block.

```ruby
class CommentsByAuthorQuery < Quo::RelationBackedQuery
  prop :author_id, Integer
  def query
    Comment.joins(:post).where(posts: {author_id: author_id})
  end
end

query = CommentsByAuthorQuery.new(author_id: 1)
  .transform { |comment| CommentPresenter.new(comment) }

query.results.each do |presenter|
  puts presenter.formatted_body
end
```

### Inspecting

```ruby
query = CommentsByAuthorQuery.new(author_id: 1)
query.transform?  # => false

with_transform = query.transform { |c| CommentPresenter.new(c) }
with_transform.transform?  # => true
```

## Patterns

### Presenter wrapping

A typical view-layer transformer:

```ruby
class CommentPresenter
  def initialize(comment, viewer: nil)
    @comment = comment
    @viewer = viewer
  end

  def formatted_body
    @comment.body.gsub(/\b(http\S+)/, '<a href="\1">\1</a>').html_safe
  end

  def status_badge
    @comment.read? ? "✓ read" : "● unread"
  end
end

query = CommentsByAuthorQuery.new(author_id: current_user.id)
  .transform { |c| CommentPresenter.new(c, viewer: current_user) }

query.results.each do |presenter|
  puts "#{presenter.status_badge} #{presenter.formatted_body}"
end
```

### Serialization for API responses

```ruby
class CommentSerializer
  def initialize(comment, include_post: false)
    @comment = comment
    @include_post = include_post
  end

  def as_json
    base = {id: @comment.id, body: @comment.body, read: @comment.read}
    base[:post] = {id: @comment.post.id, title: @comment.post.title} if @include_post
    base
  end
end

query = CommentsByAuthorQuery.new(author_id: params[:author_id])
  .transform { |c| CommentSerializer.new(c, include_post: true) }

render json: {data: query.results.map(&:as_json)}
```

### DTO conversion

```ruby
CommentDTO = Data.define(:id, :body, :read_at)

query = CommentsByAuthorQuery.new(author_id: 1)
  .transform { |c| CommentDTO.new(id: c.id, body: c.body, read_at: c.updated_at) }

query.results.to_a  # => [CommentDTO, CommentDTO, ...]
```

### Capturing context in the transformer block

The block closes over its surrounding scope, so context flows in
naturally:

```ruby
viewer = current_user
locale = I18n.locale

query = CommentsByAuthorQuery.new(author_id: 1)
  .transform { |c| CommentPresenter.new(c, viewer: viewer, locale: locale) }
```

This works because the block is captured at `transform` time and applied
later when results are read.

## Transformers + pagination

Transformers operate on the materialised page; counts are unaffected.

```ruby
query = CommentsByAuthorQuery.new(author_id: 1, page: 1, page_size: 25)
  .transform { |c| CommentPresenter.new(c) }

results = query.results
results.first        # => CommentPresenter
results.count        # => total comments (unwrapped count)
results.page_count   # => 25 presenters in current page
```

Page navigation preserves the transformer:

```ruby
next_query = query.next_page_query
next_query.transform?  # => true
next_query.results.first  # => CommentPresenter
```

## Transformers + composition

### Compose, then transform

The natural order: build the query first, transform last.

```ruby
base   = AllCommentsQuery.new
filter = UnreadCommentsQuery.new
(base + filter).transform { |c| CommentPresenter.new(c) }.results
```

### Transform, then compose

The transformer carries through composition.

```ruby
transformed = AllCommentsQuery.new.transform { |c| CommentPresenter.new(c) }
filtered    = transformed + UnreadCommentsQuery.new
filtered.results.first  # => CommentPresenter
```

### Multiple `transform` calls

The most recent one wins. Quo doesn't pipeline transformers — each
`#transform` replaces any prior one.

```ruby
query = AllCommentsQuery.new
  .transform { |c| CommentPresenter.new(c) }
  .transform { |c| CommentSerializer.new(c) }

query.results.first  # => CommentSerializer (the last transformer)
```

If you want a pipeline, compose the work inside a single block:

```ruby
query = AllCommentsQuery.new.transform { |c|
  CommentSerializer.new(CommentPresenter.new(c))
}
```

## Method delegation

`Quo::Results` delegates `Enumerable` methods to the underlying
collection, applying the transformer on each yielded row.

```ruby
results = CommentsByAuthorQuery.new(author_id: 1)
  .transform { |c| CommentPresenter.new(c) }
  .results

results.map(&:formatted_body)
results.select { |p| p.status_badge.include?("unread") }
results.group_by(&:status_badge)
results.first
```

These all return transformed rows. `#count`, `#page_count`, `#empty?`,
and `#exists?` work on the underlying data — they aren't transformed.

## Performance considerations

### Lazy

Transformers run when results are read, not when `#transform` is called.

```ruby
query = AllCommentsQuery.new.transform { |c|
  puts "transforming #{c.id}"
  CommentPresenter.new(c)
}
# Nothing prints yet.

query.results.each { |p| ... }
# Now "transforming N" prints for each row.
```

### Keep transformers cheap

A transformer that does heavy work per row will dominate query time.
Prefer a lightweight wrapper that defers expensive work to method
calls.

```ruby
# Heavy — runs for every row, even if you only need .id
.transform { |c| HeavyPresenter.new(c).tap(&:precompute_everything!) }

# Light — defers work until needed
.transform { |c| LazyPresenter.new(c) }
```

### Memoize inside the wrapper

If a presenter computes something expensive per call, memoize:

```ruby
class CommentPresenter
  def initialize(comment); @comment = comment; end

  def author_display
    @author_display ||= @comment.post.author.name.titleize
  end
end
```

## Testing transformers

```ruby
class CommentsByAuthorQueryTransformerTest < ActiveSupport::TestCase
  setup do
    @author = Author.create!(name: "Ada")
    @post = Post.create!(title: "Hi", author: @author)
    Comment.create!(post: @post, body: "first")
  end

  test "wraps each row in a presenter" do
    query = CommentsByAuthorQuery.new(author_id: @author.id)
      .transform { |c| CommentPresenter.new(c) }

    assert_instance_of CommentPresenter, query.results.first
  end

  test "transformer applies to all enumerable methods" do
    query = CommentsByAuthorQuery.new(author_id: @author.id)
      .transform { |c| CommentPresenter.new(c) }

    bodies = query.results.map(&:formatted_body)
    assert_equal 1, bodies.size
  end

  test "#transform? reports true after transform" do
    query = CommentsByAuthorQuery.new(author_id: @author.id)
    refute query.transform?

    transformed = query.transform { |c| CommentPresenter.new(c) }
    assert transformed.transform?
  end
end
```
