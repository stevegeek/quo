# Query Composition and Transformation

This document explains Quo's powerful composition system and transformation capabilities.

## Composition Overview

Quo implements a sophisticated composition system that allows queries to be combined using the `+` operator or `compose` method. The composition strategy is automatically selected based on the types being composed.

## Composition Architecture

### Strategy Pattern Implementation

```ruby
module Quo
  module Composing
    # Main entry points
    def self.composer(chosen_superclass, left_query_class, right_query_class, joins: nil, left_spec: nil, right_spec: nil)
      registry = ClassStrategyRegistry.new
      strategy = registry.find_strategy(left_query_class, right_query_class)
      strategy.compose(chosen_superclass, left_query_class, right_query_class, joins: joins, left_spec: left_spec, right_spec: right_spec)
    end
    
    def self.merge_instances(left_instance, right_instance, joins: nil)
      registry = InstanceStrategyRegistry.new
      strategy = registry.find_strategy(left_instance, right_instance)
      strategy.compose(left_instance, right_instance, joins: joins)
    end
  end
end
```

### Composition Strategies

Quo implements different strategies based on what's being composed:

1. **RelationAndRelationStrategy** - Composing two relation-backed queries
2. **RelationAndQueryStrategy** - Composing a relation with any query
3. **QueryAndRelationStrategy** - Composing any query with a relation
4. **QueryAndQueryStrategy** - Composing two arbitrary queries
5. **QueryClassesStrategy** - Composing query classes (not instances)

## Class-Level Composition

### Basic Class Composition

```ruby
# Define base queries
class ActiveUsersQuery < Quo::RelationBackedQuery
  def query
    User.where(active: true)
  end
end

class PremiumUsersQuery < Quo::RelationBackedQuery
  def query
    User.where(subscription: "premium")
  end
end

# Compose at class level
ActivePremiumQuery = ActiveUsersQuery + PremiumUsersQuery

# Or with explicit method
ActivePremiumQuery = ActiveUsersQuery.compose(PremiumUsersQuery)

# Use the composed class
query = ActivePremiumQuery.new(page: 1)
results = query.results  # Active AND premium users
```

### Composed Query Implementation

When queries are composed, Quo creates a new `ComposedQuery` class:

```ruby
module Quo
  class ComposedQuery < Query
    class << self
      attr_accessor :_left_class, :_right_class, :_joins
    end
    
    # Properties from both queries are merged
    # Left query properties take precedence in conflicts
    
    def query
      # Combines queries based on their types
      merge_instances(left_query, right_query)
    end
  end
end
```

### Property Inheritance

```ruby
class FilteredUsersQuery < Quo::RelationBackedQuery
  prop :min_age, Integer
  prop :role, String
  
  def query
    User.where("age >= ?", min_age).where(role: role)
  end
end

class LocationUsersQuery < Quo::RelationBackedQuery
  prop :city, String
  prop :state, String
  
  def query
    User.where(city: city, state: state)
  end
end

# Composed query has all properties
ComposedQuery = FilteredUsersQuery + LocationUsersQuery

query = ComposedQuery.new(
  min_age: 21,
  role: "admin",
  city: "New York",
  state: "NY"
)
```

## Instance-Level Composition

### Basic Instance Composition

```ruby
# Create query instances
active_users = ActiveUsersQuery.new
premium_users = PremiumUsersQuery.new

# Compose instances
combined = active_users + premium_users
# Or
combined = active_users.merge(premium_users)

results = combined.results
```

### Composition with Joins

```ruby
# Define queries that need joins
class PublishedPostsQuery < Quo::RelationBackedQuery
  def query
    Post.where(published: true)
  end
end

class ActiveAuthorsQuery < Quo::RelationBackedQuery
  def query
    Author.where(active: true)
  end
end

# Compose with explicit join
posts = PublishedPostsQuery.new
authors = ActiveAuthorsQuery.new

# Method 1: Using joins parameter
combined = posts.compose(authors, joins: :author)

# Method 2: Chaining joins before composition
combined = posts.joins(:author) + authors

# Results in: SELECT posts.* FROM posts 
#            INNER JOIN authors ON authors.id = posts.author_id
#            WHERE posts.published = true AND authors.active = true
```

### Complex Join Examples

```ruby
# Multiple joins
posts_with_comments = posts.compose(
  CommentQuery.new,
  joins: [:author, :comments]
)

# Nested joins
posts_with_nested = posts.compose(
  CategoryQuery.new,
  joins: { author: :profile, comments: :user }
)

# Hash conditions in joins
posts_with_conditions = posts.compose(
  AuthorQuery.new,
  joins: { author: { profile: :preferences } }
)
```

## Mixed Type Composition

### Relation + Collection

```ruby
# Start with a relation query
class BaseUsersQuery < Quo::RelationBackedQuery
  def query
    User.where(deleted_at: nil)
  end
end

# Have a collection of special users
class SpecialUsersQuery < Quo::CollectionBackedQuery
  def collection
    # From cache, API, etc
    [
      User.new(id: 1, name: "Admin"),
      User.new(id: 2, name: "Support")
    ]
  end
end

# Compose them
combined = BaseUsersQuery.new + SpecialUsersQuery.new
# Results include both database users AND special users
```

### How Mixed Composition Works

When composing different types:

1. If either is a collection, result is collection-backed
2. Relations are converted to arrays via `to_a`
3. Collections are concatenated
4. Duplicates are NOT automatically removed

```ruby
# Under the hood for Relation + Collection
def compose_relation_and_collection(relation_query, collection_query)
  relation_results = relation_query.results.to_a
  collection_results = collection_query.results.to_a
  
  Quo::CollectionBackedQuery.wrap(relation_results + collection_results)
end
```

## Transformation System

### Basic Transformation

```ruby
# Transform results after fetching
users_query = UsersByStateQuery.new(state: "CA")
  .transform { |user| UserPresenter.new(user) }

# All result methods return transformed objects
users_query.results.each do |presenter|
  puts presenter.display_name  # Not user.name
end

users_query.results.first  # Returns UserPresenter, not User
users_query.results.map(&:to_json)  # Maps over presenters
```

### Transformation Implementation

```ruby
# Inside Quo::Query
def transform(&block)
  @__transformer = block
  self
end

# Inside Results classes
def transform_results(results)
  return results unless transform?
  
  if results.is_a?(Enumerable)
    results.map.with_index { |item, i| @transformer.call(item, i) }
  else
    @transformer.call(results)
  end
end
```

### Index-Aware Transformation

```ruby
# Transformer receives optional index
query.transform do |user, index|
  {
    position: index + 1,
    name: user.name,
    email: user.email
  }
end

# First user gets position: 1, second gets position: 2, etc.
```

### Chaining Transformations

```ruby
# Note: Only last transformation is applied
users_query
  .transform { |u| UserDecorator.new(u) }      # This is overwritten
  .transform { |u| UserPresenter.new(u) }      # This is applied

# To chain transformations, compose in one block
users_query.transform do |user|
  decorated = UserDecorator.new(user)
  UserPresenter.new(decorated)
end
```

## Advanced Composition Patterns

### Repository Pattern

```ruby
class UserRepository
  def active
    @active ||= ActiveUsersQuery
  end
  
  def premium
    @premium ||= PremiumUsersQuery
  end
  
  def verified
    @verified ||= VerifiedUsersQuery
  end
  
  def active_premium_verified
    active + premium + verified
  end
end

repo = UserRepository.new
users = repo.active_premium_verified.new.results
```

### Dynamic Composition

```ruby
class SearchQuery < Quo::RelationBackedQuery
  prop :filters, Hash, default: -> { {} }
  
  def query
    base = User.all
    
    # Dynamically compose queries based on filters
    queries_to_compose = []
    
    queries_to_compose << ActiveUsersQuery if filters[:active]
    queries_to_compose << PremiumUsersQuery if filters[:premium]
    queries_to_compose << VerifiedUsersQuery if filters[:verified]
    
    queries_to_compose.reduce(base) do |combined, query_class|
      combined + query_class.new
    end
  end
end
```

### Conditional Composition

```ruby
class ConditionalQuery < Quo::RelationBackedQuery
  prop :include_archived, Boolean, default: -> { false }
  prop :user_id, Integer
  
  def query
    base = Post.where(user_id: user_id)
    
    if include_archived
      base + ArchivedPostsQuery.new(user_id: user_id)
    else
      base
    end
  end
end
```

## Composition Performance

### Efficient Database Queries

When composing relation-backed queries:

```ruby
# Good: Single database query
active_premium = ActiveUsersQuery.new + PremiumUsersQuery.new
users = active_premium.results  # One query with merged conditions

# SQL: SELECT users.* FROM users WHERE active = true AND subscription = 'premium'
```

### Memory Considerations

When composing with collections:

```ruby
# Caution: Loads all records into memory
relation_query = User.where(active: true)  # Could be millions
collection_query = SpecialUsersQuery.new   # Just a few

combined = relation_query + collection_query
# This executes relation_query.to_a - loads ALL active users!
```

### Best Practices

1. **Compose similar types when possible** - Relation + Relation is most efficient
2. **Use joins parameter for associations** - Avoids N+1 queries
3. **Transform after composition** - More efficient than transforming each query
4. **Be mindful of collection size** - Mixed composition loads relations into memory
5. **Consider caching** - For expensive composed queries

## Testing Composed Queries

```ruby
# Test composition behavior
class ComposedQueryTest < ActiveSupport::TestCase
  test "combines filters from both queries" do
    left = ActiveUsersQuery.new
    right = PremiumUsersQuery.new
    
    composed = left + right
    sql = composed.to_sql
    
    assert_includes sql, "active = true"
    assert_includes sql, "subscription = 'premium'"
  end
  
  test "transformation applies to composed results" do
    composed = (ActiveUsersQuery.new + PremiumUsersQuery.new)
      .transform { |u| u.name.upcase }
    
    fake_query(composed.__class__, results: [User.new(name: "john")]) do
      result = composed.results.first
      assert_equal "JOHN", result
    end
  end
end
```