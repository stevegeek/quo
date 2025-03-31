# Quo: Query Objects for ActiveRecord

Quo helps you organize database queries into reusable, composable, and testable objects.

## Core Features

* Wrap around an underlying ActiveRecord relation or array-like collection
* Supports pagination for ActiveRecord-based queries and collections that respond to `[]`
* Support composition with the `+` (`compose`) method to merge multiple query objects
* Allow transforming results with the `transform` method
* Offer utility methods that operate on the underlying collection (eg `exists?`)
* Act as a callable with chainable methods like ActiveRecord
* Provide a clear separation between query definition and execution with enumerable `Results` objects
* Type-safe properties with optional default values

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

## Quick Queries with Wrap

Create query objects without subclassing:

```ruby
# Relation-backed
users_query = Quo::RelationBackedQuery.wrap(User.active).new
active_users = users_query.results

# Collection-backed
items_query = Quo::CollectionBackedQuery.wrap([1, 2, 3]).new
items = items_query.results
```

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

## Fluent API for Building Queries

```ruby
query = UsersByState.new(state: "California")
  .order(created_at: :desc)
  .includes(:profile)
  .limit(10)
  .where(verified: true)

users = query.results
```

Available methods include:
* `where`
* `order`
* `limit`
* `includes`
* `preload`
* `left_outer_joins`
* `joins`
* `group`

Each method returns a new query instance without modifying the original.

## Pagination

```ruby
query = UsersByState.new(
  state: "California",
  page: 2,
  page_size: 20
)

# Get paginated results
users = query.results

# Navigation
next_page = query.next_page_query
prev_page = query.previous_page_query
```

## Composing Queries

Combine multiple queries:

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

# Compose queries
active_premium = ActiveUsers.new + PremiumUsers.new
users = active_premium.results
```

You can compose queries using:
* `Quo::Query.compose(left, right)`
* `left.compose(right)`
* `left + right`

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

## Transforming Results

```ruby
query = UsersByState.new(state: "California")
  .transform { |user| UserPresenter.new(user) }

# Results are automatically transformed
presenters = query.results.to_a # Array of UserPresenter objects
```

## Custom Association Preloading

```ruby
class UsersWithOrders < Quo::RelationBackedQuery
  include Quo::Preloadable
  
  def query
    User.all
  end

  def preload_associations(collection)
    # Custom preloading logic
    ActiveRecord::Associations::Preloader.new(
      records: collection,
      associations: [:profile, :orders]
    ).call
    
    collection
  end
end
```

## Testing Helpers

### Minitest

```ruby
class UserQueryTest < ActiveSupport::TestCase
  include Quo::Minitest::Helpers

  test "filters users by state" do
    users = [User.new(name: "Alice"), User.new(name: "Bob")]
    
    fake_query(UsersByState, results: users) do
      result = UsersByState.new(state: "California").results.to_a
      assert_equal users, result
    end
  end
end
```

### RSpec

```ruby
RSpec.describe UsersByState do
  include Quo::RSpec::Helpers

  it "filters users by state" do
    users = [User.new(name: "Alice"), User.new(name: "Bob")]
    
    fake_query(UsersByState, results: users) do
      result = UsersByState.new(state: "California").results.to_a
      expect(result).to eq(users)
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

```ruby
# config/initializers/quo.rb
Quo.default_page_size = 25
Quo.max_page_size = 100
Quo.relation_backed_query_base_class = "ApplicationQuery"
Quo.collection_backed_query_base_class = "ApplicationCollectionQuery"
```

## Requirements

- Ruby 3.1+
- Rails 7.0+

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/stevegeek/quo.

## Inspired by `rectify`

This implementation is inspired by the `Rectify` gem: https://github.com/andypike/rectify. Thanks to Andy Pike for the inspiration.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
