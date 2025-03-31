# Quo: Query Objects for ActiveRecord & Collections

Quo helps you organize database and collection queries into reusable, composable, and testable objects.

## Quick Example

```ruby
# Define query objects to encapsulate query logic
class RecentPostsQuery < Quo::RelationBackedQuery
  # Type-safe properties with defaults
  prop :days_ago, Integer, default: -> { 7 }
  
  def query
    Post.where(Post.arel_table[:created_at].gt(days_ago.days.ago))
      .order(created_at: :desc)
  end
end

# Use queries with pagination
posts_query = RecentPostsQuery.new(days_ago: 30, page: 1, page_size: 10)
page1 = posts_query.results
# => Returns first 10 posts from the last 30 days

# Navigate between pages
page2_query = posts_query.next_page_query
page2 = page2_query.results
# => Returns next 10 posts

class CommentNotSpamQuery < Quo::RelationBackedQuery
  prop :spam_score_threshold, _Float(0..1.0)

  def query
    comments = Comment.arel_table
    Comment.where(
      comments[:spam_score].eq(nil).or(comments[:spam_score].lt(spam_score_threshold))
    )
  end
end

# Get recent posts (last 10 days) which have comments that are not Spam
posts_last_10_days = RecentPostsQuery.new(days_ago: 10).joins(:comments)

# Compose your queries
query = posts_last_10_days + CommentNotSpamQuery.new(spam_score_threshold: 0.5)

# Transform results
transformed_query = query.transform { |post| PostPresenter.new(post) }

# Work with result sets
transformed_query.results.each do |presenter|
  puts presenter.formatted_title
end
```


## Core Features

### Collections
* Query objects can wrap either an ActiveRecord relation (`RelationBackedQuery`) or any Enumerable collection (`CollectionBackedQuery`)
* Built-in pagination that works with both database queries and enumerable collections
* Flexible interface for creating custom queries or wrapping existing queries

### Configurable
* Type-safe properties with optional default values using the Literal gem
* Each query is (kinda) "immutable" - operations return new query instances, mutation is actively frowned upon
* Configure your own base classes, default page sizes, and more

### Composition and Transformation
* Combine queries using the `+` operator (alias for `compose` method)
* Mix and match relation-backed and collection-backed queries
* Join queries with explicit join conditions using the `joins` parameter
* Transform results consistently using the `transform` method

### Fluent API
* Chain methods that mirror ActiveRecord's query interface (where, order, limit, etc.)
* Access utility methods that work on both relation and collection queries (exists?, empty?, etc.)
* Navigation helpers for pagination (next_page_query, previous_page_query)

### Query Results
* Clear separation between query definition and execution with `Results` objects
* Automatic application of transformations across all result methods
* Consistent interface regardless of the underlying query type
* Support for common methods: each, map, first/last, count, exists?, group_by, and more


## Core Concepts

Query objects encapsulate query logic in dedicated classes, making complex queries more manageable and reusable.

Quo provides two main components:
1. **Query Objects** - Define and configure queries
2. **Results Objects** - Execute queries and provide access to the results

## Creating Query Objects

### Relation-Backed Queries

For queries based on ActiveRecord relations:

```ruby
class RecentActiveUsers < Quo::RelationBackedQuery
  # Define typed properties
  prop :days_ago, Integer, default: -> { 30 }
  
  def query
    User
      .where(active: true)
      .where("created_at > ?", days_ago.days.ago)
  end
end

# Create and use the query
query = RecentActiveUsers.new(days_ago: 7)
results = query.results

# Work with results
results.each { |user| puts user.email }
puts "Found #{results.count} users"
```

### Collection-Backed Queries

For queries based on any Enumerable collection:

```ruby
class CachedUsers < Quo::CollectionBackedQuery
  prop :role, String
  
  def collection
    @cached_users ||= Rails.cache.fetch("all_users", expires_in: 1.hour) do
      User.all.to_a
    end.select { |user| user.role == role }
  end
end

# Use the query
admins = CachedUsers.new(role: "admin").results
```

## Quick Queries with Wrap and to_collection

### Creating Query Objects with Wrap

Create query objects on the fly without subclassing using the `wrap` class method:

```ruby
# Relation-backed query from an ActiveRecord relation
users_query = Quo::RelationBackedQuery.wrap(User.active).new
active_users = users_query.results

# Relation-backed query with a block
posts_query = Quo::RelationBackedQuery.wrap(props: {tag: String}) do
  Post.where(published: true).where("title LIKE ?", "%#{tag}%")
end
tagged_posts = posts_query.new(tag: "ruby").results

# Collection-backed query from an array
items_query = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
items = items_query.results

# Collection-backed query with properties and a block
filtered_query = Quo::CollectionBackedQuery.wrap(props: {min: Integer}) do
  [1, 2, 3, 4, 5].select { |n| n >= min }
end
result = filtered_query.new(min: 3).results # [3, 4, 5]
```

### Converting Between Query Types

Convert a relation-backed query to a collection-backed query using `to_collection`:

```ruby
# Start with a relation-backed query
relation_query = UsersByState.new(state: "California")

# Convert to a collection-backed query (executes the query)
collection_query = relation_query.to_collection
collection_query.collection? # => true
collection_query.relation? # => false

# You can optionally specify a total count (useful for pagination)
collection_query = relation_query.to_collection(total_count: 100)
```

This is useful when you want to convert an ActiveRecord relation to an enumerable collection while preserving the query interface.

## Type-Safe Properties

Quo uses the `Literal` gem for typed properties:

```ruby
class UsersByState < Quo::RelationBackedQuery
  prop :state, String
  prop :minimum_age, Integer, default: -> { 18 }
  prop :active_only, Boolean, default: -> { true }

  def query
    scope = User.where(state: state)
    scope = scope.where("age >= ?", minimum_age) if minimum_age.present?
    scope = scope.where(active: true) if active_only
    scope
  end
end

query = UsersByState.new(state: "California", minimum_age: 21)
```

## Pagination

```ruby
query = UsersByState.new(
  state: "California",
  page: 2,
  page_size: 20
)

# Get paginated results for page 2 with 20 items
users = query.results

# Navigation to next and previous pages creates new queries
next_page = query.next_page_query
prev_page = query.previous_page_query
```

## Composing Queries

Quo provides extensive query composition capabilities, letting you combine multiple query objects:

```ruby
class ActiveUsers < Quo::RelationBackedQuery
  def query
    User.where(active: true)
  end
end

class PremiumUsers < Quo::RelationBackedQuery
  def query
    User.where(subscription_tier: "premium")
  end
end

# Compose queries using the + operator
active_premium = ActiveUsers.new + PremiumUsers.new
users = active_premium.results
```

You can compose queries in several ways:
* At the class level: `ActiveUsers.compose(PremiumUsers)` or `ActiveUsers + PremiumUsers`
* At the instance level: `active_query.compose(premium_query)` or `active_query + premium_query`
* With joins: `active_query.compose(premium_query, joins: :some_association)`

Quo handles different composition scenarios automatically:
* Relation + Relation: Uses ActiveRecord's merge capabilities
* Relation + Collection: Combines the results of both
* Collection + Collection: Concatenates the collections

For example, to compose query objects with proper joins:

```ruby
# Query for posts
class PostsQuery < Quo::RelationBackedQuery
  def query
    Post.where(published: true)
  end
end

# Query for authors
class AuthorsQuery < Quo::RelationBackedQuery
  def query
    Author.where(active: true)
  end
end

# Compose with a joins parameter to specify the relationship
composed_query = PostsQuery.new.compose(AuthorsQuery.new, joins: :author)
# You can also use this equivalent form:
# composed_query = PostsQuery.new.joins(:author) + AuthorsQuery.new

# Returns published posts by active authors
results = composed_query.results
```


## Utility Methods

Quo query objects provide several utility methods to help you work with them:

```ruby
query = UsersByState.new(state: "California")

# Check query type
query.relation?   # => true if backed by an ActiveRecord relation
query.collection? # => true if backed by a collection

# Check pagination status
query.paged?      # => true if pagination is enabled (page is set)

# Check transformation status
query.transform?  # => true if a transformer is set

# Get the raw underlying query without pagination
raw_query = query.unwrap_unpaginated  # => The ActiveRecord relation or collection

# Get the configured query with pagination
configured_query = query.unwrap  # => The query with pagination applied

# For RelationBackedQuery, get SQL representation
puts query.to_sql  # => "SELECT users.* FROM users WHERE users.state = 'California'"
```

## Transforming Results

```ruby
query = UsersByState.new(state: "California")
  .transform { |user| UserPresenter.new(user) }

# Results are automatically transformed
presenters = query.results.to_a # Array of UserPresenter objects
```

## Working with Results Objects

When you call `.results` on a query object, you get a `Results` object that wraps the underlying collection and ensures consistent application of transformations.

```ruby
# Create a query with a transformer
users_query = UsersByState.new(state: "California")
  .transform { |user| UserPresenter.new(user) }

# Get results - transformations are applied consistently
results = users_query.results

# Existence checks
results.exists?  # => true/false
results.empty?   # => false/true

# Count methods
results.count        # Total count of results (ignoring pagination)
results.total_count  # Same as count
results.size         # Same as count
results.page_count   # Count of items on current page (respects pagination)
results.page_size    # Same as page_count

# Enumerable methods - all respect transformations
results.each { |presenter| puts presenter.formatted_name }
results.map { |presenter| presenter.email }
results.select { |presenter| presenter.active? }
results.reject { |presenter| presenter.inactive? }
results.first  # Returns the first transformed item
results.last   # Returns the last transformed item
results.first(3)  # Returns the first 3 transformed items
results.to_a  # Returns all transformed items as an array

# ActiveRecord extensions (for RelationResults)
results.find(123)  # Find by id and transform
results.find_by(email: "user@example.com")  # Find by attributes and transform
results.where(active: true)  # Returns a new Results with the condition applied

# Methods are delegated to the underlying collection
# and transformations are applied consistently
results.group_by(&:role)  # Groups transformed objects by role
```

Quo provides two types of Results objects:
- `RelationResults` - For ActiveRecord-based queries, delegates to the underlying relation
- `CollectionResults` - For collection-based queries, delegates to the enumerable collection

## Fluent API for Building Queries

Quo implements a fluent API that mirrors ActiveRecord's query interface, allowing you to chain methods that build up your query:

```ruby
# Start with a base query
query = UsersByState.new(state: "California")

# Chain method calls to build your query
refined_query = query
  .order(created_at: :desc)    # Order results
  .includes(:profile, :posts)  # Eager load associations
  .joins(:posts)               # Join with posts
  .where(verified: true)       # Add conditions
  .limit(10)                   # Limit results
  .group("users.role")         # Group results
  
# Original query remains unchanged
original_results = query.results
refined_results = refined_query.results

# You can further refine as needed
admin_query = refined_query.where(role: "admin")
```

Available methods for relation-backed queries include:
* `where` - Add conditions to the query
* `not` - Negate conditions
* `or` - Add OR conditions
* `order` - Set the order of results
* `reorder` - Replace existing order
* `limit` - Limit the number of results
* `offset` - Set an offset for results
* `includes` - Eager load associations
* `preload` - Preload associations
* `eager_load` - Eager load with LEFT OUTER JOIN
* `joins` - Add inner joins
* `left_outer_joins` - Add left outer joins
* `group` - Group results
* `select` - Specify columns to select
* `distinct` - Return distinct results

Each method returns a new query instance without modifying the original, ensuring queries are immutable and can be safely composed.

## Association Preloading in Collection-Backed Queries

When working with enumerable collections of ActiveRecord models, you can still preload associations to avoid N+1 queries. This is particularly useful when you have collections that don't come directly from the database but still need efficient association loading.

Include the `Quo::Preloadable` module in your collection-backed query and use the `includes` or `preload` methods:

```ruby
class FirstAndLastUsers < Quo::CollectionBackedQuery
  include Quo::Preloadable
  
  def collection
    [User.first, User.last] # These users come from separate queries
  end
end

# Preload the profiles and posts for both users in a single efficient query
query = FirstAndLastUsers.new.includes(:profile, :posts)

# Check that the association is loaded
query.results.first.profile.loaded? # => true
query.results.last.posts.loaded? # => true

# Access the preloaded associations without triggering additional queries
query.results.each do |user|
  puts "#{user.name} has #{user.posts.size} posts"
end
```

The `Preloadable` module overrides the `query` method to apply ActiveRecord's preloader to your collection.

### Composing with Joins

```ruby
class ProductsQuery < Quo::RelationBackedQuery
  def query
    Product.where(active: true)
  end
end

class CategoriesQuery < Quo::RelationBackedQuery
  def query
    Category.where(featured: true)
  end
end

# Compose with a join
products = ProductsQuery.new.compose(CategoriesQuery.new, joins: :category)

# Equivalent to:
# Product.joins(:category)
#        .where(products: { active: true })
#        .where(categories: { featured: true })
```

## Testing Helpers

Quo provides testing helpers for both Minitest and RSpec to make your query objects easy to test in isolation.

### Minitest

The `Quo::Minitest::Helpers` module includes the `fake_query` method that lets you mock query results without hitting the database:

```ruby
class UserQueryTest < ActiveSupport::TestCase
  include Quo::Minitest::Helpers

  test "filters users by state" do
    # Create test data
    users = [User.new(name: "Alice"), User.new(name: "Bob")]
    
    # Mock the query results within the block
    fake_query(UsersByState, results: users) do
      # Any instance of UsersByState created inside this block
      # will return the mocked results regardless of query parameters
      result = UsersByState.new(state: "California").results.to_a
      assert_equal users, result
      
      # You can create multiple instances with different parameters
      other_result = UsersByState.new(state: "New York").results.to_a
      assert_equal users, other_result
    end
    
    # After the block, normal behavior resumes
  end
  
  test "works with pagination" do
    users = (1..10).map { |i| User.new(name: "User #{i}") }
    
    fake_query(UsersByState, results: users) do
      # Pagination still works with fake query results
      paginated = UsersByState.new(state: "California", page: 1, page_size: 5).results
      assert_equal 5, paginated.page_count
      assert_equal 10, paginated.total_count
    end
  end
end
```

### RSpec

The same functionality is available for RSpec through the `Quo::RSpec::Helpers` module:

```ruby
RSpec.describe UsersByState do
  include Quo::RSpec::Helpers

  it "filters users by state" do
    users = [User.new(name: "Alice"), User.new(name: "Bob")]
    
    fake_query(UsersByState, results: users) do
      result = UsersByState.new(state: "California").results.to_a
      expect(result).to eq(users)
      
      # Test that transformations still work
      transformed = UsersByState.new(state: "California")
        .transform { |user| user.name.upcase }
        .results
        
      expect(transformed.first).to eq("ALICE")
    end
  end
  
  it "can be nested for testing composed queries" do
    users = [User.new(name: "Alice", active: true)]
    premium_users = [User.new(name: "Bob", subscription: "premium")]
    
    # Nested fake_query calls for testing composition
    fake_query(ActiveUsers, results: users) do
      fake_query(PremiumUsers, results: premium_users) do
        composed = ActiveUsers.new + PremiumUsers.new
        expect(composed.results.count).to eq(2)
      end
    end
  end
end
```

## Project Organization

Suggested directory structure:

```
app/
  queries/
    application_query.rb
    users/
      active_users_query.rb
      by_state_query.rb
    products/
      featured_products_query.rb
```

Base classes:

```ruby
# app/queries/application_query.rb
class ApplicationQuery < Quo::RelationBackedQuery
  # Common functionality
end

# app/queries/application_collection_query.rb
class ApplicationCollectionQuery < Quo::CollectionBackedQuery
  # Common functionality
end
```

## Installation

Add to your Gemfile:

```ruby
gem "quo"
```

Then execute:

```
$ bundle install
```

## Configuration

Quo provides several configuration options to customize its behavior to your needs. Configure these in an initializer:

```ruby
# config/initializers/quo.rb
module Quo
  # Set the default number of items per page (default: 20)
  self.default_page_size = 25
  
  # Set the maximum allowed page size to prevent excessive resource usage (default: 200)
  self.max_page_size = 100
  
  # Set custom base classes for your queries
  # These must be string names of constantizable classes that inherit from 
  # Quo::RelationBackedQuery and Quo::CollectionBackedQuery respectively
  self.relation_backed_query_base_class = "ApplicationQuery"
  self.collection_backed_query_base_class = "ApplicationCollectionQuery"
end
```

Using custom base classes lets you add functionality that's shared across all your query objects in your application.

## Requirements

- Ruby 3.1+
- Rails 7.0+, 8.0+

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/stevegeek/quo.

## Inspired by `rectify`

This implementation is inspired by the `Rectify` gem: https://github.com/andypike/rectify. Thanks to Andy Pike for the inspiration.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
