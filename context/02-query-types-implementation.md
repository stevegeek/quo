# Query Types and Implementation

This document details the two primary query types in Quo and their implementation patterns.

## RelationBackedQuery Deep Dive

### Core Implementation

```ruby
class RelationBackedQuery < Query
  # Specification pattern for storing query options
  prop :_specification, _Nilable(Quo::RelationBackedQuerySpecification),
    default: -> { RelationBackedQuerySpecification.blank },
    writer: false

  # Must return an ActiveRecord::Relation or another Quo::Query
  def query
    raise NotImplementedError
  end
  
  # Returns RelationResults for execution
  def results
    Quo::RelationResults.new(self, transformer: transformer)
  end
  
  # Fluent API implementation
  def method_missing(method_name, *args, **kwargs, &block)
    spec = @_specification || RelationBackedQuerySpecification.blank
    
    if spec.respond_to?(method_name)
      updated_spec = spec.method(method_name).call(*args, **kwargs, &block)
      return with_specification(updated_spec)
    end
    
    super
  end
end
```

### Practical Example

```ruby
class PublishedPostsQuery < Quo::RelationBackedQuery
  # Type-safe properties
  prop :author_id, _Nilable(Integer)
  prop :since_date, _Nilable(Date), default: -> { 30.days.ago.to_date }
  prop :category, _Nilable(String)
  
  def query
    posts = Post.published
    posts = posts.where(author_id: author_id) if author_id
    posts = posts.where("published_at >= ?", since_date) if since_date
    posts = posts.joins(:categories).where(categories: { name: category }) if category
    posts
  end
end

# Usage with fluent API
query = PublishedPostsQuery.new(author_id: 123)
  .order(published_at: :desc)
  .includes(:author, :comments)
  .limit(10)

results = query.results
```

### Query Specification Pattern

The specification pattern separates query construction from storage:

```ruby
# Building a complex query
spec = RelationBackedQuerySpecification.blank
  .where(active: true)
  .where("created_at > ?", 1.week.ago)
  .order(created_at: :desc)
  .includes(:profile)
  .limit(10)

# Apply to any relation
spec.apply_to(User.all)  # => Returns configured relation
```

### Wrap Factory Method

Create query objects on the fly without defining a class:

```ruby
# Simple wrap
ActiveUsersQuery = Quo::RelationBackedQuery.wrap(User.where(active: true))

# With properties
FilteredUsersQuery = Quo::RelationBackedQuery.wrap(
  props: { 
    role: String,
    min_age: _Nilable(Integer)
  }
) do
  scope = User.all
  scope = scope.where(role: role) if role
  scope = scope.where("age >= ?", min_age) if min_age
  scope
end

# Usage
query = FilteredUsersQuery.new(role: "admin", min_age: 18)
```

### SQL Generation

RelationBackedQuery provides SQL introspection:

```ruby
query = UsersByStateQuery.new(state: "CA")
puts query.to_sql
# => "SELECT users.* FROM users WHERE users.state = 'CA'"
```

## CollectionBackedQuery Deep Dive

### Core Implementation

```ruby
class CollectionBackedQuery < Query
  # Optional total count for pagination
  prop :total_count, _Nilable(Integer), reader: false
  
  # Must return an Enumerable
  def collection
    raise NotImplementedError
  end
  
  # Default implementation delegates to collection
  def query
    collection
  end
  
  # Returns CollectionResults for execution
  def results
    Quo::CollectionResults.new(self, transformer: transformer, total_count: @total_count)
  end
  
  # Pagination support
  def configured_query
    q = underlying_query
    return q unless paged?
    
    if q.respond_to?(:[])
      q[offset, sanitised_page_size]  # Array-like slicing
    else
      q  # Non-sliceable collections
    end
  end
end
```

### Practical Examples

#### Working with Cached Data

```ruby
class CachedProductsQuery < Quo::CollectionBackedQuery
  prop :min_price, _Nilable(Float)
  prop :category, _Nilable(String)
  
  def collection
    @products ||= Rails.cache.fetch("all_products", expires_in: 1.hour) do
      Product.includes(:variants, :images).to_a
    end
    
    filtered = @products
    filtered = filtered.select { |p| p.price >= min_price } if min_price
    filtered = filtered.select { |p| p.category == category } if category
    filtered
  end
end
```

#### Working with External APIs

```ruby
class GitHubRepositoriesQuery < Quo::CollectionBackedQuery
  prop :username, String
  prop :language, _Nilable(String)
  
  def collection
    repos = fetch_github_repos(username)
    repos = repos.select { |r| r["language"] == language } if language
    repos
  end
  
  private
  
  def fetch_github_repos(username)
    response = Net::HTTP.get_response(
      URI("https://api.github.com/users/#{username}/repos")
    )
    JSON.parse(response.body)
  end
end
```

#### Working with Non-Database Models

```ruby
class FileSystemQuery < Quo::CollectionBackedQuery
  prop :directory, String, default: -> { "." }
  prop :extension, _Nilable(String)
  
  def collection
    files = Dir.glob(File.join(directory, "**/*"))
    files = files.select { |f| f.end_with?(extension) } if extension
    files.map { |path| FileInfo.new(path) }
  end
end

FileInfo = Struct.new(:path) do
  def name
    File.basename(path)
  end
  
  def size
    File.size(path)
  end
end
```

### Preloadable Module

Enable association preloading for collections of ActiveRecord models:

```ruby
class SpecialUsersQuery < Quo::CollectionBackedQuery
  include Quo::Preloadable
  
  def collection
    # These come from different sources
    [
      User.find_by(email: "admin@example.com"),
      User.find_by(role: "superuser"),
      User.where(vip: true).first
    ].compact
  end
end

# Preload associations efficiently
query = SpecialUsersQuery.new.includes(:profile, :posts)
query.results.each do |user|
  # No N+1 queries!
  puts "#{user.name} has #{user.posts.count} posts"
end
```

### Wrap Factory Method

```ruby
# Simple collection wrap
NumbersQuery = Quo::CollectionBackedQuery.wrap([1, 2, 3, 4, 5])

# With filtering logic
FilteredNumbersQuery = Quo::CollectionBackedQuery.wrap(
  props: { min: Integer }
) do
  (1..100).select { |n| n >= min }
end

# Usage
query = FilteredNumbersQuery.new(min: 50, page: 1, page_size: 10)
results = query.results
```

## Conversion Between Types

### to_collection Method

Convert a RelationBackedQuery to a CollectionBackedQuery:

```ruby
# Start with a relation query
relation_query = UsersByStateQuery.new(state: "NY")

# Convert to collection (executes the query)
collection_query = relation_query.to_collection

# Can specify total count for accurate pagination
collection_query = relation_query.to_collection(total_count: 1000)

# Now it behaves as a collection
collection_query.collection?  # => true
collection_query.relation?    # => false
```

This is useful for:
- Caching query results
- Working with results in memory
- Applying Ruby-based filtering to SQL results

## Query Method Contracts

### Required Methods

Both query types must implement:

1. **query** - Returns the data source (relation or collection)
2. **validated_query** - Validates and returns the query
3. **underlying_query** - Returns the query without pagination
4. **configured_query** - Returns the query with pagination applied

### Type Checking

```ruby
# RelationBackedQuery validates type
def validated_query
  query.tap do |q|
    raise ArgumentError, "#query must return an ActiveRecord Relation or a Quo::Query instance" 
      unless query.nil? || q.is_a?(::ActiveRecord::Relation) || q.is_a?(Quo::Query)
  end
end

# CollectionBackedQuery has no validation
def validated_query
  query  # Any enumerable is valid
end
```

## Performance Considerations

### RelationBackedQuery

- Queries are lazy - SQL only executes when results are accessed
- Supports database-level optimizations (indexes, joins)
- Efficient counting via SQL COUNT
- Memory efficient for large datasets

### CollectionBackedQuery

- Data must fit in memory
- Filtering happens in Ruby (potentially slower)
- Flexible - works with any data source
- Good for cached data or small datasets

## Choosing the Right Type

Use **RelationBackedQuery** when:
- Working directly with ActiveRecord models
- Need database-level filtering and joins
- Working with large datasets
- Need SQL-level performance

Use **CollectionBackedQuery** when:
- Working with cached data
- Data comes from external APIs
- Need Ruby-level transformations
- Working with non-AR objects
- Dataset fits comfortably in memory