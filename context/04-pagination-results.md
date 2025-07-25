# Pagination and Results

This document covers Quo's pagination system and the Results objects that execute queries and provide access to data.

## Pagination System

### Core Pagination Properties

Every Quo query has built-in pagination support via two properties:

```ruby
class Query < Literal::Struct
  # Current page number (nil means no pagination)
  prop :page, _Nilable(Integer), &COERCE_TO_INT
  
  # Items per page (defaults to Quo.default_page_size)
  prop :page_size, _Nilable(Integer), 
    default: -> { Quo.default_page_size || 20 }, 
    &COERCE_TO_INT
end
```

### Pagination Implementation

#### For RelationBackedQuery

```ruby
def configured_query
  q = underlying_query
  return q unless paged?  # paged? returns true if page is set
  
  q.offset(offset).limit(sanitised_page_size)
end

def offset
  per_page = sanitised_page_size
  page_with_default = page&.positive? ? page : 1
  per_page * (page_with_default - 1)
end
```

SQL translation:
- Page 1, size 20: `LIMIT 20 OFFSET 0`
- Page 2, size 20: `LIMIT 20 OFFSET 20`
- Page 3, size 10: `LIMIT 10 OFFSET 20`

#### For CollectionBackedQuery

```ruby
def configured_query
  q = underlying_query
  return q unless paged?
  
  if q.respond_to?(:[])
    q[offset, sanitised_page_size]  # Array slicing
  else
    q  # Non-sliceable collections return unchanged
  end
end
```

### Page Size Sanitization

```ruby
def sanitised_page_size
  if page_size&.positive?
    given_size = page_size.to_i
    max_page_size = Quo.max_page_size || 200
    
    # Enforce maximum to prevent resource abuse
    given_size > max_page_size ? max_page_size : given_size
  else
    Quo.default_page_size || 20
  end
end
```

### Navigation Methods

```ruby
query = UsersQuery.new(page: 2, page_size: 20)

# Get next page query (immutable - returns new instance)
next_page = query.next_page_query
next_page.page  # => 3

# Get previous page query
prev_page = query.previous_page_query  
prev_page.page  # => 1

# Previous page never goes below 1
first_page = UsersQuery.new(page: 1)
prev = first_page.previous_page_query
prev.page  # => 1 (not 0)
```

### Pagination Examples

```ruby
# Basic pagination
users = UsersQuery.new(page: 1, page_size: 25).results

# Iterate through pages
query = UsersQuery.new(page: 1, page_size: 100)
all_users = []

loop do
  results = query.results
  all_users.concat(results.to_a)
  
  break if results.to_a.size < query.page_size
  query = query.next_page_query
end

# Pagination with other options
query = UsersQuery.new(
  state: "CA",
  page: 3,
  page_size: 50
).order(:created_at)
```

## Results Objects

### Results Base Class

```ruby
module Quo
  class Results
    def initialize(query, transformer: nil, **options)
      @query = query
      @transformer = transformer
      @configured_query = query.unwrap
    end
    
    # Counting methods
    def count         # Total count (ignores pagination)
    def total_count   # Alias for count
    def size          # Alias for count  
    def page_count    # Count on current page only
    def page_size     # Alias for page_count
    
    # Existence methods
    def exists?
    def empty?
    
    # Enumerable interface
    def each(&block)
    def map(&block)
    def first(limit = nil)
    def last(limit = nil)
    
    # Delegation with transformation
    def method_missing(method, *args, **kwargs, &block)
  end
end
```

### RelationResults

Specialized for ActiveRecord relations:

```ruby
class RelationResults < Results
  delegate :model, :klass, to: :@query
  
  def count
    # Efficient SQL count
    @unpaginated_relation.count
  end
  
  def total_count
    # For compatibility
    count
  end
  
  def page_count
    # Only counts current page
    @configured_query.count
  end
  
  def exists?
    @configured_query.exists?
  end
  
  def find(id)
    result = @configured_query.find(id)
    transform? ? @transformer.call(result) : result
  end
  
  def find_by(conditions)
    result = @configured_query.find_by(conditions)
    return nil unless result
    transform? ? @transformer.call(result) : result
  end
  
  def where(conditions)
    # Returns new Results with additional conditions
    self.class.new(
      @query.copy,
      configured_query: @configured_query.where(conditions),
      transformer: @transformer
    )
  end
end
```

### CollectionResults

Specialized for enumerable collections:

```ruby
class CollectionResults < Results
  def initialize(query, transformer: nil, total_count: nil)
    super(query, transformer: transformer)
    @total_count = total_count
  end
  
  def count
    # Counts full collection or uses provided total
    @total_count || @query.unwrap_unpaginated.count
  end
  
  def page_count
    # Counts items on current page
    @configured_query.count
  end
  
  def exists?
    !@configured_query.empty?
  end
  
  def to_a
    arr = @configured_query.to_a
    transform? ? arr.map.with_index { |x, i| @transformer.call(x, i) } : arr
  end
end
```

### Working with Results

```ruby
# Get results
query = UsersQuery.new(state: "CA", page: 1, page_size: 20)
results = query.results

# Counting
results.count        # Total users in CA (ignores pagination)
results.page_count   # Users on current page (max 20)
results.total_count  # Same as count

# Existence checks
if results.exists?
  puts "Found #{results.count} users"
else
  puts "No users found"
end

# Enumeration
results.each do |user|
  puts user.name
end

# Get specific items
first_user = results.first
last_user = results.last
first_five = results.first(5)

# Map/Select/Reject with transformation
emails = results.map(&:email)
active = results.select(&:active?)

# For RelationResults - ActiveRecord methods
user = results.find(123)
admin = results.find_by(role: "admin")
californians = results.where(state: "CA")
```

## Transformation in Results

### How Transformation Works

```ruby
# Set transformer on query
query = UsersQuery.new.transform { |user| UserPresenter.new(user) }
results = query.results

# All methods return transformed objects
results.first        # => UserPresenter instance
results.to_a         # => Array of UserPresenter instances
results.map(&:name)  # => Calls name on UserPresenter, not User
```

### Transformation Implementation

```ruby
# In Results base class
def transform_results(results)
  return results unless transform?
  
  if results.is_a?(Enumerable)
    results.map.with_index { |item, i| @transformer.call(item, i) }
  else
    @transformer.call(results)
  end
end

# Method missing handles transformation
def method_missing(method, *args, **kwargs, &block)
  if block
    @configured_query.send(method, *args, **kwargs) do |*block_args|
      x = block_args.first
      transformed = transform? ? @transformer.call(x) : x
      block.call(transformed, *(block_args[1..] || []))
    end
  else
    raw = @configured_query.send(method, *args, **kwargs)
    transform_results(raw)
  end
end
```

### Special Case: group_by

```ruby
# group_by has special handling to transform both keys and values
query = UsersQuery.new.transform { |u| UserPresenter.new(u) }

grouped = query.results.group_by(&:role)
# Returns: { "admin" => [UserPresenter, ...], "user" => [UserPresenter, ...] }

# Custom grouping
grouped = query.results.group_by { |presenter| presenter.created_at.year }
# Groups presenters by year
```

## Pagination Patterns

### API Pagination

```ruby
class UsersController < ApplicationController
  def index
    query = UsersQuery.new(
      page: params[:page]&.to_i || 1,
      page_size: params[:per_page]&.to_i || 25
    )
    
    results = query.results
    
    render json: {
      users: results.to_a,
      pagination: {
        current_page: query.page,
        per_page: query.page_size,
        total_count: results.total_count,
        total_pages: (results.total_count.to_f / query.page_size).ceil,
        has_next: results.page_count == query.page_size,
        has_previous: query.page > 1
      }
    }
  end
end
```

### Cursor-Based Pagination

```ruby
class CursorPaginatedQuery < Quo::RelationBackedQuery
  prop :cursor, _Nilable(String)
  prop :limit, Integer, default: -> { 20 }
  
  def query
    scope = User.order(:id)
    
    if cursor
      decoded_id = Base64.decode64(cursor).to_i
      scope = scope.where("id > ?", decoded_id)
    end
    
    scope.limit(limit + 1)  # Fetch one extra to check for more
  end
  
  def results_with_cursor
    items = results.to_a
    has_more = items.size > limit
    items = items[0...limit] if has_more
    
    next_cursor = if has_more && items.any?
      Base64.encode64(items.last.id.to_s).strip
    end
    
    {
      data: items,
      next_cursor: next_cursor,
      has_more: has_more
    }
  end
end
```

### Infinite Scroll

```ruby
class InfiniteScrollQuery < Quo::RelationBackedQuery
  prop :last_id, _Nilable(Integer)
  prop :batch_size, Integer, default: -> { 50 }
  
  def query
    scope = Post.order(created_at: :desc)
    scope = scope.where("id < ?", last_id) if last_id
    scope.limit(batch_size)
  end
end

# Frontend makes requests:
# GET /posts?last_id=123&batch_size=50
```

## Performance Considerations

### Count Performance

```ruby
# For RelationResults - uses SQL COUNT
results.count  # SELECT COUNT(*) FROM users WHERE ...

# For CollectionResults - counts in memory
results.count  # Calls .count on the array

# Optimization: Pass total_count when converting
relation_query = UsersQuery.new
total = relation_query.results.count  # Get count via SQL

collection_query = relation_query.to_collection(total_count: total)
collection_query.results.count  # Uses cached total, no counting needed
```

### Large Result Sets

```ruby
# Bad: Loads everything into memory
users = UsersQuery.new.results.to_a  # Could be millions!

# Good: Process in batches
query = UsersQuery.new(page: 1, page_size: 1000)

loop do
  results = query.results
  
  results.each do |user|
    # Process user
  end
  
  break if results.page_count < query.page_size
  query = query.next_page_query
end

# Better: Use ActiveRecord's find_each for relations
UsersQuery.new.unwrap.find_each(batch_size: 1000) do |user|
  # Process user
end
```

### Pagination Edge Cases

```ruby
# Empty results
query = UsersQuery.new(page: 999, page_size: 20)
results = query.results
results.count       # => 0 (total count)
results.page_count  # => 0 (current page)
results.exists?     # => false

# Single page
query = UsersQuery.new(page: 1, page_size: 1000)
results = query.results  # If total users < 1000
next_page = query.next_page_query.results
next_page.empty?  # => true

# No pagination
query = UsersQuery.new  # No page set
query.paged?  # => false
results = query.results  # Returns all results
```