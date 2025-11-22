---
layout: default
title: API Reference
nav_order: 3
permalink: /api
---

# API Reference

## Query Object Classes

### Quo::RelationBackedQuery

Base class for queries that work with ActiveRecord relations.

```ruby
class MyQuery < Quo::RelationBackedQuery
  prop :some_filter, String

  def query
    MyModel.where(column: some_filter)
  end
end
```

**Key Methods:**
- `query` - Must be implemented to return an ActiveRecord relation
- `results` - Returns a Results object with the query results
- `unwrap` - Returns the underlying relation with pagination applied
- `unwrap_unpaginated` - Returns the underlying relation without pagination
- `to_sql` - Returns the SQL representation of the query

### Quo::CollectionBackedQuery

Base class for queries that work with any Enumerable collection.

```ruby
class MyCollectionQuery < Quo::CollectionBackedQuery
  prop :filter_value, String

  def collection
    [1, 2, 3, 4, 5].select { |n| n > filter_value.to_i }
  end
end
```

**Key Methods:**
- `collection` - Must be implemented to return an Enumerable
- `results` - Returns a Results object with the collection results
- `unwrap` - Returns the underlying collection with pagination applied
- `unwrap_unpaginated` - Returns the underlying collection without pagination

## Common Query Methods

Both query types support these methods:

### Property Definition

```ruby
prop :property_name, Type, default: -> { default_value }
```

Define typed properties using [Literal types](https://github.com/joeldrapper/literal). Common examples:

```ruby
# Basic types
prop :name, String
prop :age, Integer
prop :active, _Boolean  # Use _Boolean for true/false

# Optional types
prop :email, String | nil

# Collections
prop :tags, _Array(String)
prop :metadata, _Hash(Symbol, String)
```

### Pagination

```ruby
MyQuery.new(page: 1, page_size: 20)
query.next_page_query
query.previous_page_query
query.paged? # => true/false
```

### Composition

```ruby
# Instance-level: Merge query instances
query1 + query2                              # Returns a new query instance
query1.merge(query2)                         # Returns a new query instance
query1.merge(query2, joins: :association)    # Returns a new query instance

# Class-level: Compose query classes
ComposedQuery = Query1 + Query2              # Returns a new query CLASS
ComposedQuery = Query1.compose(Query2)       # Returns a new query CLASS
ComposedQuery.new                            # Create an instance of composed class
```

### Transformation

```ruby
# Transform results with a block
query.transform { |item| ItemPresenter.new(item) }
query.transform { |item, index| ItemPresenter.new(item, position: index) }
query.transform? # => true/false
```

### Fluent API (RelationBackedQuery)

Chain ActiveRecord methods to build complex queries:

```ruby
# Filtering, ordering, and associations
query.where(column: value)
query.select(:column1, :column2)
query.order(created_at: :desc)
query.reorder(updated_at: :asc)
query.joins(:association)
query.left_outer_joins(:association)
query.includes(:profile, :posts)  # Alias for preload (not ActiveRecord's includes)
query.preload(:comments)
query.eager_load(:tags)

# Limiting and grouping
query.limit(10).offset(5)
query.group(:category).distinct

# Advanced
query.extending(MyQueryExtension)
query.unscope(:order, :limit)
```

### Query Helpers

```ruby
# Check query type
query.relation?   # => true if backed by ActiveRecord relation
query.collection? # => true if backed by a collection

# Create a query class from a relation or collection
# IMPORTANT: wrap returns a new query CLASS, not an instance!
MyQuery = Quo::RelationBackedQuery.wrap(User.active)
instance = MyQuery.new  # Must call .new to create an instance

# With dynamic properties - still returns a CLASS
MyQuery = Quo::RelationBackedQuery.wrap(props: {role: String}) { User.where(role: role) }
instance = MyQuery.new(role: "admin")  # Must call .new with props

# Convert a RelationBackedQuery to CollectionBackedQuery (executes the query)
collection_query = query.to_collection
collection_query = query.to_collection(total_count: 100)  # Optional total count
```

## Results Objects

### RelationResults

Returned by `RelationBackedQuery#results`.

**Methods:**
- `each`, `map`, `select`, `reject` - Enumerable methods with transformation support
- `first`, `last`, `first(n)`, `last(n)` - Access specific items
- `count`, `total_count`, `size` - Total count of ALL results (ignores pagination)
- `page_count`, `page_size` - Count of items on CURRENT page only
- `exists?`, `empty?` - Existence checks
- `to_a` - Convert to array
- `find(id)`, `find_by(attributes)` - ActiveRecord finder methods

**Note:** Transformations are applied to all items returned by result methods.

### CollectionResults

Returned by `CollectionBackedQuery#results`.

**Methods:**
- Same as RelationResults, except ActiveRecord-specific methods like `find` and `find_by`

## Configuration

```ruby
module Quo
  # Set custom base classes
  self.relation_backed_query_base_class = "ApplicationQuery"
  self.collection_backed_query_base_class = "ApplicationCollectionQuery"

  # Configure pagination defaults
  self.default_page_size = 25  # Default: 20
  self.max_page_size = 100     # Default: 200
end
```

## Preloading Associations (CollectionBackedQuery)

Preload associations for CollectionBackedQuery objects containing ActiveRecord models:

```ruby
class FirstAndLastPosts < Quo::CollectionBackedQuery
  include Quo::Preloadable

  def collection
    [Post.first, Post.last]
  end
end

# Preload associations to avoid N+1 queries
query = FirstAndLastPosts.new.includes(:author, :comments)

# Access preloaded data without additional queries
query.results.each do |post|
  puts "#{post.title} by #{post.author.name} (#{post.comments.count} comments)"
end
```

**Note:** Quo's `includes` is an alias for `preload` (not ActiveRecord's `includes` which uses eager loading). Both preload associations without joining.

## Testing Helpers

### Minitest

```ruby
include Quo::Minitest::Helpers

# Basic usage
fake_query(MyQuery, results: [item1, item2]) do
  result = MyQuery.new.results.to_a
  assert_equal [item1, item2], result
end

# With pagination metadata
fake_query(MyQuery, results: [item1, item2], total_count: 100, page_count: 2) do
  results = MyQuery.new.results
  assert_equal 100, results.total_count  # Total across all pages
  assert_equal 2, results.page_count     # Items on current page
end
```

### RSpec

```ruby
include Quo::Rspec::Helpers

# Basic usage
fake_query(MyQuery, results: [item1, item2]) do
  result = MyQuery.new.results.to_a
  expect(result).to eq([item1, item2])
end

# With specific argument expectations
fake_query(MyQuery, with: {role: "admin"}, results: [admin1, admin2]) do
  result = MyQuery.new(role: "admin").results.to_a
  expect(result).to eq([admin1, admin2])
end

# With pagination metadata
fake_query(MyQuery, results: [item1, item2], total_count: 100, page_count: 2) do
  results = MyQuery.new.results
  expect(results.total_count).to eq(100)  # Total across all pages
  expect(results.page_count).to eq(2)     # Items on current page
end
```
