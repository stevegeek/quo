# Quo Core Architecture

This document provides a technical deep-dive into Quo's architecture, explaining how the gem is structured and how its components work together to provide composable query objects.

## Foundation: Literal Framework

Quo is built on top of the [Literal](https://github.com/joeldrapper/literal) gem, leveraging its type-safe property system. Every query object inherits from `Literal::Struct`, providing:

- Type-checked properties with defaults
- Immutable struct-like behavior
- Built-in validation and coercion

## Core Class Hierarchy

```
Literal::Struct
    └── Quo::Query (abstract base)
        ├── Quo::RelationBackedQuery
        │   └── Application-specific query classes
        └── Quo::CollectionBackedQuery
            └── Application-specific query classes
```

### Quo::Query

The abstract base class that defines the core interface for all query objects:

```ruby
class Query < Literal::Struct
  include Literal::Types
  
  # Core properties for pagination
  prop :page, _Nilable(Integer), &COERCE_TO_INT
  prop :page_size, _Nilable(Integer), default: -> { Quo.default_page_size || 20 }, &COERCE_TO_INT
  
  # Abstract methods that subclasses must implement
  def query
    raise NotImplementedError
  end
  
  # Key instance methods
  def copy(**overrides)
  def merge(right, joins: nil)  # aliased as +
  def transform(&block)
  def results
end
```

Key responsibilities:
- Defines pagination interface (page, page_size)
- Provides composition capabilities via `merge`/`+`
- Supports result transformation via `transform`
- Enforces contract through abstract methods

### Quo::RelationBackedQuery

Specializes Query for ActiveRecord relations:

```ruby
class RelationBackedQuery < Query
  prop :_specification, _Nilable(Quo::RelationBackedQuerySpecification)
  
  def query
    # Returns ActiveRecord::Relation
  end
  
  def results
    Quo::RelationResults.new(self, transformer: transformer)
  end
  
  # Fluent API via method_missing
  def method_missing(method_name, *args, **kwargs, &block)
    # Delegates to RelationBackedQuerySpecification
  end
end
```

Key features:
- Wraps ActiveRecord relations
- Uses `RelationBackedQuerySpecification` to store query options
- Provides fluent API matching ActiveRecord's interface
- Returns `RelationResults` for execution

### Quo::CollectionBackedQuery

Specializes Query for enumerable collections:

```ruby
class CollectionBackedQuery < Query
  prop :total_count, _Nilable(Integer), reader: false
  
  def collection
    # Returns Enumerable
  end
  
  def query
    collection  # Default implementation
  end
  
  def results
    Quo::CollectionResults.new(self, transformer: transformer, total_count: @total_count)
  end
end
```

Key features:
- Wraps any Enumerable collection
- Supports explicit total_count for pagination
- Can include `Quo::Preloadable` for association preloading
- Returns `CollectionResults` for execution

## Query Specification Pattern

The `RelationBackedQuerySpecification` class implements the Specification pattern to encapsulate query-building logic:

```ruby
class RelationBackedQuerySpecification
  attr_reader :options
  
  def initialize(options = {})
    @options = options
  end
  
  def merge(new_options)
    self.class.new(options.merge(new_options))
  end
  
  def apply_to(relation)
    # Applies all stored options to the relation
    rel = relation
    rel = rel.where(options[:where]) if options[:where]
    rel = rel.order(options[:order]) if options[:order]
    # ... etc
    rel
  end
  
  # Fluent methods that return new specifications
  def where(conditions)
    merge(where: conditions)
  end
  
  def order(order_clause)
    merge(order: order_clause)
  end
  # ... etc
end
```

This separation allows:
- Immutable query building
- Deferred execution
- Easy composition of query options
- Testability without database access

## Results Architecture

The Results classes provide a consistent interface for working with query results:

```
Quo::Results (abstract)
    ├── Quo::RelationResults
    └── Quo::CollectionResults
```

### Results Base Class

```ruby
class Results
  def initialize(query, transformer: nil, **options)
    @query = query
    @transformer = transformer
    @configured_query = query.unwrap
  end
  
  # Core counting methods
  def count        # Total count ignoring pagination
  def page_count   # Count on current page
  def exists?
  def empty?
  
  # Enumerable methods with transformation
  def each(&block)
  def map(&block)
  def first
  def last
  
  # Delegation with transformation support
  def method_missing(method, *args, **kwargs, &block)
    # Applies transformer when delegating to underlying collection
  end
end
```

### RelationResults

Specializes Results for ActiveRecord relations:
- Delegates to the underlying ActiveRecord::Relation
- Provides ActiveRecord-specific methods (find, find_by, where)
- Handles count efficiently via SQL
- Supports chaining (returns new Results objects)

### CollectionResults

Specializes Results for enumerable collections:
- Delegates to the underlying Enumerable
- Handles pagination via array slicing
- Supports explicit total_count
- Works with any Ruby collection

## Configuration System

Quo provides module-level configuration via `mattr_accessor`:

```ruby
module Quo
  mattr_accessor :relation_backed_query_base_class, default: "Quo::RelationBackedQuery"
  mattr_accessor :collection_backed_query_base_class, default: "Quo::CollectionBackedQuery"
  mattr_accessor :max_page_size, default: 200
  mattr_accessor :default_page_size, default: 20
end
```

This allows applications to:
- Define custom base classes with shared behavior
- Set application-wide pagination defaults
- Enforce maximum page sizes for security

## Autoloading Strategy

Quo uses Rails' autoloading for lazy loading of components

## Engine Integration

For Rails applications, Quo provides an Engine:

```ruby
module Quo
  class Engine < ::Rails::Engine
    isolate_namespace Quo
  end
end
```

This enables:
- Proper Rails integration
- Rake task loading
- Future extensibility for Rails-specific features