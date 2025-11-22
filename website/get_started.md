---
layout: default
title: Core API
nav_order: 2
has_children: true
permalink: /get-started
---

# Quo Core API

This section covers the core functionality of Quo, including:

- Creating query objects
- Working with relations and collections
- Type-safe properties
- Pagination
- Query composition
- Result transformation
- Fluent API methods

## Quick Overview

Quo provides two main types of query objects:

1. **RelationBackedQuery** - For ActiveRecord relations
2. **CollectionBackedQuery** - For any Enumerable collection

Both types support:
- Type-safe properties with the Literal gem
- Built-in pagination
- Query composition
- Result transformation
- Fluent API for chaining operations

```ruby
class PublishedPostsQuery < Quo::RelationBackedQuery
  prop :published, _Boolean, default: -> { true }
  
  def query
    Post.where(published: published)
  end
end

class FeaturedPostsQuery < Quo::RelationBackedQuery
  def query
    Post.where(featured: true)
  end
end

# Compose queries
published_and_featured = PublishedPostsQuery.new + FeaturedPostsQuery.new
published_and_featured.results.map { |post| puts post.inspect }
```


# Configuration

Quo provides several configuration options to customize its behavior.

## Configuration Options

Create an initializer to configure Quo:

```ruby
# config/initializers/quo.rb
module Quo
  # Set custom base classes for your queries
  # These must be string names of constantizable classes
  self.relation_backed_query_base_class = "ApplicationQuery"
  self.collection_backed_query_base_class = "ApplicationCollectionQuery"

  # Configure pagination defaults
  self.default_page_size = 25  # Default: 20
  self.max_page_size = 100     # Default: 200
end
```


## Custom Base Classes

You can define your own base classes for queries to add application-specific functionality:

```ruby
# app/queries/application_query.rb
class ApplicationQuery < Quo::RelationBackedQuery
  # Add common scopes, methods, or properties

  def with_tenant(tenant_id)
    where(tenant_id: tenant_id)
  end
end

# app/queries/application_collection_query.rb
class ApplicationCollectionQuery < Quo::CollectionBackedQuery
  # Add common collection processing
end
```

Then configure Quo to use these base classes:

```ruby
# config/initializers/quo.rb
module Quo
  # Note: These are stored as strings and constantized when accessed
  # This allows the configuration to be set before the classes are loaded
  self.relation_backed_query_base_class = "ApplicationQuery"
  self.collection_backed_query_base_class = "ApplicationCollectionQuery"
end
```

Now all your queries can inherit from these custom base classes:

```ruby
class UsersQuery < ApplicationQuery
  def query
    User.all.with_tenant(current_tenant_id)
  end
end
```

## Project Organization

Suggested directory structure:

```
app/
  queries/
    application_query.rb
    application_collection_query.rb
    users/
      active_users_query.rb
      by_role_query.rb
    posts/
      published_posts_query.rb
      recent_posts_query.rb
```

This organization keeps your query objects well-organized and easy to find.


# Usage Examples

This page provides real-world examples of using Quo in your Rails application.

## Basic Query Object

```ruby
class ActiveUsersQuery < Quo::RelationBackedQuery
  def query
    User.where(active: true)
  end
end

# Usage
active_users = ActiveUsersQuery.new.results.to_a
```

## Query with Properties

```ruby
class UsersByRoleQuery < Quo::RelationBackedQuery
  prop :role, String
  prop :active_only, _Boolean, default: -> { true }

  def query
    scope = User.where(role: role)
    scope = scope.where(active: true) if active_only
    scope
  end
end

# Usage
admins = UsersByRoleQuery.new(role: "admin").results
all_moderators = UsersByRoleQuery.new(role: "moderator", active_only: false).results
```

## Pagination

```ruby
class PostsQuery < Quo::RelationBackedQuery
  prop :published_only, _Boolean, default: -> { true }

  def query
    scope = Post.order(created_at: :desc)
    scope = scope.where(published: true) if published_only
    scope
  end
end

# Usage with pagination
page1 = PostsQuery.new(page: 1, page_size: 20).results
page2 = PostsQuery.new(page: 2, page_size: 20).results

# Navigate between pages
query = PostsQuery.new(page: 1, page_size: 20)
next_query = query.next_page_query
prev_query = query.previous_page_query
```

## Query Composition

```ruby
class PublishedPostsQuery < Quo::RelationBackedQuery
  def query
    Post.where(published: true)
  end
end

class FeaturedPostsQuery < Quo::RelationBackedQuery
  def query
    Post.where(featured: true)
  end
end

# Compose queries
published_and_featured = PublishedPostsQuery.new + FeaturedPostsQuery.new
results = published_and_featured.results
```

## Composition with Joins

```ruby
class PostsByAuthorQuery < Quo::RelationBackedQuery
  prop :author_name, String

  def query
    Author.where("name LIKE ?", "%#{author_name}%")
  end
end

class PublishedPostsQuery < Quo::RelationBackedQuery
  def query
    Post.where(published: true)
  end
end

# Compose with explicit joins
posts = PublishedPostsQuery.new
  .merge(PostsByAuthorQuery.new(author_name: "John"), joins: :author)
  .results
```

## Result Transformation

```ruby
class UserPresenter
  attr_reader :user, :position

  def initialize(user, position: nil)
    @user = user
    @position = position
  end

  def formatted_name
    prefix = position ? "#{position + 1}. " : ""
    "#{prefix}#{user.first_name} #{user.last_name}"
  end
end

# Apply transformation
query = ActiveUsersQuery.new
  .transform { |user| UserPresenter.new(user) }

# With index parameter
query = ActiveUsersQuery.new
  .transform { |user, index| UserPresenter.new(user, position: index) }

query.results.each do |presenter|
  puts presenter.formatted_name
end
```

## Collection-Backed Queries

```ruby
class TopRatedItemsQuery < Quo::CollectionBackedQuery
  prop :minimum_rating, _Float(0..5.0), default: -> { 4.0 }

  def collection
    # Maybe from a cache or external API
    cached_items = Rails.cache.fetch("all_items") { Item.all.to_a }
    cached_items.select { |item| item.rating >= minimum_rating }
  end
end

# Usage
top_items = TopRatedItemsQuery.new(minimum_rating: 4.5).results
```

## Fluent API

```ruby
query = PostsQuery.new
  .where(category: "Technology")
  .order(published_at: :desc)
  .includes(:author, :comments)
  .limit(10)

results = query.results
```

## Testing with Helpers

### Minitest

```ruby
class UserQueryTest < ActiveSupport::TestCase
  include Quo::Minitest::Helpers

  test "returns active users" do
    users = [User.new(name: "Alice"), User.new(name: "Bob")]

    fake_query(ActiveUsersQuery, results: users) do
      result = ActiveUsersQuery.new.results.to_a
      assert_equal users, result
    end
  end
end
```

### RSpec

```ruby
RSpec.describe ActiveUsersQuery do
  include Quo::Rspec::Helpers

  it "returns active users" do
    users = [User.new(name: "Alice"), User.new(name: "Bob")]

    fake_query(ActiveUsersQuery, results: users) do
      result = ActiveUsersQuery.new.results.to_a
      expect(result).to eq(users)
    end
  end
end
```

## Advanced: Converting Relations to Collections

```ruby
# Start with a relation-backed query
relation_query = ActiveUsersQuery.new

# Convert to collection-backed (executes the query)
collection_query = relation_query.to_collection

# Now you can work with it as a collection
collection_query.collection? # => true
```

## Advanced: Wrapping Existing Relations

```ruby
# Wrap an existing relation
users_query = Quo::RelationBackedQuery.wrap(User.active).new
results = users_query.results

# With properties
tagged_posts = Quo::RelationBackedQuery.wrap(props: {tag: String}) do
  Post.where(published: true).where("title LIKE ?", "%#{tag}%")
end

results = tagged_posts.new(tag: "ruby").results
```

