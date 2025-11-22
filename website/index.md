---
layout: home
title: Introduction
nav_order: 1
permalink: /
---

# Quo: Query Objects for ActiveRecord & Collections
{: .fs-9 }

Composable, testable, and reusable query objects for Ruby on Rails
{: .fs-6 .fw-300 }

## What is Quo?

`quo` is a Ruby gem that helps you organize database and collection queries into reusable, composable, and testable objects. It provides a clean, fluent API for building complex queries while maintaining type safety and immutability.

## Why use Quo?

- **Organize complex queries**: Encapsulate query logic in dedicated, testable classes
- **Composable**: Combine multiple query objects using the `+` operator
- **Type-safe**: Built on the Literal gem for typed properties with validation
- **Pagination built-in**: Automatic pagination support for both database and collection queries
- **Flexible**: Works with both ActiveRecord relations and plain Ruby collections
- **Fluent API**: Chain methods just like ActiveRecord
- **Testing helpers**: Built-in test helpers for Minitest and RSpec

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

# Compose queries
class CommentNotSpamQuery < Quo::RelationBackedQuery
  prop :spam_score_threshold, _Float(0..1.0)

  def query
    comments = Comment.arel_table
    Comment.where(
      comments[:spam_score].eq(nil).or(comments[:spam_score].lt(spam_score_threshold))
    )
  end
end

# Get recent posts (last 10 days) which have comments that are not spam
posts_last_10_days = RecentPostsQuery.new(days_ago: 10).joins(:comments)
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

### Type-Safe Properties
* Use the Literal gem for typed properties with optional default values
* Each query is immutable - operations return new query instances
* Configure your own base classes, default page sizes, and more

### Composition and Transformation
* Combine queries using the `+` operator or `merge` method at instance level
* Compose query classes using `Query1.compose(Query2)` at class level
* Mix and match relation-backed and collection-backed queries
* Join queries with explicit join conditions
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

## Getting Started

Explore the documentation to learn more:

- [Getting Started Guide](/get-started) - Configuration, examples, and usage patterns
- [API Reference](/api) - Detailed API documentation

## Installation

Add to your Gemfile:

```ruby
gem "quo"
```

Then execute:

```
$ bundle install
```

## Requirements

- Ruby 3.2+
- Rails 7.2+

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/stevegeek/quo](https://github.com/stevegeek/quo).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Inspiration

This implementation is inspired by the [Rectify](https://github.com/andypike/rectify) gem by Andy Pike. Thanks for the inspiration!

**Key differences to Quo:**
- Much broader scope—bundles forms, presenters, commands, AND queries where Quo focuses only on queries
- No longer actively maintained
- Uses Wisper pub/sub pattern for commands; Quo has simpler return values
- Lacks the type-safety emphasis that Quo provides
- Query composition with `|` operator directly inspired Quo's composable design

**Quo as an alternative?**

Quo can be seen as a successor to Rectify's query object concepts.

## More detail

- [API Reference](/api) - Detailed API documentation


