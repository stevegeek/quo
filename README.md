# 'Quo' query objects for ActiveRecord

Quo query objects can help you abstract ActiveRecord DB queries into reusable and composable objects with a chainable
interface.

The query object can also abstract over any array-like collection meaning that it is possible for example to cache the
data from a query and reuse it.

The core implementation provides the following functionality:

* wrap around an underlying ActiveRecord or array-like collection
* optionally provides paging behaviour to ActiveRecord based queries
* provides a number of utility methods that operate on the underlying collection (eg `exists?`)
* provides a `+` (`compose`) method which merges two query object instances (see section below for details!)
* can specify a mapping or transform method to `transform` to perform on results
* acts as a callable which executes the underlying query with `.first`
* can return an `Enumerable` of results

## Creating a Quo query object

The query object must inherit from `Quo::Query` and provide an implementation for the `query` method.

The `query` method must return either:

- an `ActiveRecord::Relation`
- an Array (an 'eager loaded' query) 
- or another `Quo::Query` instance.

Remember that the query object should be useful in composition with other query objects. Thus it should not directly 
specify things that are not directly needed to fetch the right data for the given context. 

For example the ordering of the results is mostly something that is specified when the query object is used, not as
part of the query itself (as then it would always enforce the ordering on other queries it was composed with).

## Passing options to queries

If any parameters are need in `query`, these are provided when instantiating the query object using the `options` hash.

It is also possible to pass special configuration options to the constructor options hash. 

Specifically when the underlying collection is a ActiveRecord relation then:

* `order`: the `order` condition for the relation (eg `:desc`)
* `includes`: the `includes` condition for the relation (eg `account: {user: :profile}`)
* `group`: the `group` condition for the relation
* `page`: the current page number to fetch
* `page_size`: the number of elements to fetch in the page

Note that the above options have no bearing on the query if it is backed by an array-like collection and that some
options can be configured using the following methods.

## Configuring queries

Note that it is possible to configure a query using chainable methods similar to ActiveRecord:

* limit
* order
* group
* includes
* left_outer_joins
* preload
* joins

Note that these return a new Quo Query and do not mutate the original instance.

## Composition of queries (merging or combining them)

Quo query objects are composeability. In `ActiveRecord::Relation` this is acheived using `merge`
and so under the hood `Quo::Query` uses that when composing relations. However since Queries can also abstract over
array-like collections (ie enumerable and define a `+` method) compose also handles concating them together.

Composing can be done with either 

- `Quo::Query.compose(left, right)` 
- or `left.compose(right)` 
- or more simply with `left + right`

The composition methods also accept an optional parameter to pass to ActiveRecord relation merges for the `joins`. 
This allows you to compose together Query objects which return relations which are of different models but still merge 
them correctly with the appropriate joins. Note with the alias you cant neatly specify optional parameters for joins
on relations.

Note that the compose process creates a new query object instance, which is a instance of a `Quo::ComposedQuery`.

Consider the following cases:

1. compose two query objects which return `ActiveRecord::Relation`s
2. compose two query objects, one of which returns a `ActiveRecord::Relation`, and the other an array-like
3. compose two query objects which return array-likes

In case (1) the compose process uses `ActiveRecords::Relation`'s `merge` method to create another query object
wrapped around a new 'composed' `ActiveRecords::Relation`.

In case (2) the query object with a `ActiveRecords::Relation` inside is executed, and the result is then concatenated
to the array-like with `+`

In case (3) the values contained with each 'eager' query object are concatenated with `+`

*Note that*

with `left.compose(right)`, `left` must obviously be an instance of a `Quo::Query`, and `right` can be either a
query object or and `ActiveRecord::Relation`. However `Quo::Query.compose(left, right)` also accepts
`ActiveRecord::Relation`s for left.

### Examples

```ruby
class CompanyToBeApproved < Quo::Query
  def query
    Registration
      .left_joins(:approval)
      .where(approvals: {completed_at: nil})
  end
end

class CompanyInUsState < Quo::Query
  def query
    Registration
      .joins(company: :address)
      .where(addresses: {state: options[:state]})
  end
end

query1 = CompanyToBeApproved.new
query2 = CompanyInUsState.new(state: "California")

# Compose
composed = query1 + query2 # or Quo::Query.compose(query1, query2) or query1.compose(query2)
composed.first
```

This effectively executes:

```ruby
Registration
  .left_joins(:approval)
  .joins(company: :address)
  .where(approvals: {completed_at: nil})
  .where(addresses: {state: options[:state]})
```

It is also possible to compose with an `ActiveRecord::Relation`. This can be useful in a Query object itself to help
build up the `query` relation. For example:

```ruby
class RegistrationToBeApproved < Quo::Query
  def query
    done = Registration.where(step: "complete")
    approved = CompanyToBeApproved.new
    # Here we use `.compose` utility method to wrap our Relation in a Query and 
    # then compose with the other Query
    Quo::Query.compose(done, approved)
  end
end

# A Relation can be composed directly to a Quo::Query
query = RegistrationToBeApproved.new + Registration.where(blocked: false)
```

Also you can use joins:

```ruby
class TagByName < Quo::Query
  def query
    Tag.where(name: options[:name])
  end
end

class CategoryByName < Quo::Query
  def query
    Category.where(name: options[:name])
  end
end

tags = TagByName.new(name: "Intel")
for_category = CategoryByName.new(name: "CPUs")
tags.compose(for_category, :category) # perform join on tag association `category`

# equivalent to Tag.joins(:category).where(name: "Intel").where(categories: {name: "CPUs"})
```

Eager loaded queries can also be composed (see below sections for more details).

### Quo::ComposedQuery

The new instance of `Quo::ComposedQuery` from a compose process, retains references to the original entities that were
composed. These are then used to create a more useful output from `to_s`, so that it is easier to understand what the
merged query is actually made up of:

```ruby
q = FooQuery.new + BarQuery.new
puts q
# > "Quo::ComposedQuery[FooQuery, BarQuery]"
```

## Query Objects & Pagination

Specify extra options to enable pagination:

* `page`: the current page number to fetch
* `page_size`: the number of elements to fetch in the page

### `Quo::CollectionBackedQuery` & `Quo::CollectionBackedQuery` objects

`Quo::CollectionBackedQuery` is a subclass of `Quo::Query` which can be used to create query objects which are 'eager loaded' by 
default. This is useful for encapsulating data that doesn't come from an ActiveRecord query or queries that
execute immediately. Subclass EasyQuery and override `collection` to return the data you want to encapsulate.

```ruby
class MyCollectionBackedQuery < Quo::CollectionBackedQuery
  def collection
    [1, 2, 3]
  end
end
q = MyCollectionBackedQuery.new
q.eager? # is it 'eager'? Yes it is!
q.count # '3'
```

Sometimes it is useful to create similar Queries without needing to create a explicit subclass of your own. For this
use `Quo::CollectionBackedQuery`:

```ruby
q = Quo::CollectionBackedQuery.new([1, 2, 3])
q.eager? # is it 'eager'? Yes it is!
q.count # '3'
```

`Quo::CollectionBackedQuery` also uses `total_count` option value as the specified 'total count', useful when the data is
actually just a page of the data and not the total count.

Example of an CollectionBackedQuery used to wrap a page of enumerable data:

```ruby
Quo::CollectionBackedQuery.new(my_data, total_count: 100, page: current_page)
```

If a loaded query is `compose`d with other Query objects then it will be seen as an array-like, and concatenated to whatever 
results are returned from the other queries. An loaded or eager query will force all other queries to be eager loaded.

### Composition

Examples of composition of eager loaded queries

```ruby
class CachedTags < Quo::Query
  def query
    @tags ||= Tag.where(active: true).to_a
  end
end

composed = CachedTags.new(active: false) + [1, 2]
composed.last
# => 2
composed.first
# => #<Tag id: ...>

Quo::CollectionBackedQuery.new([3, 4]).compose(Quo::CollectionBackedQuery.new([1, 2])).last
# => 2
Quo::Query.compose([1, 2], [3, 4]).last
# => 4
```

## Transforming results

Sometimes you want to specify a block to execute on each result for any method that returns results, such as `first`,
`last` and `each`.

This can be specified using the `transform(&block)` instance method. For example:

```ruby
TagsQuery.new(
  active: [true, false],
  page: 1,
  page_size: 30,
).transform { |tag| TagPresenter.new(tag) }
 .first
# => #<TagPresenter ...>
```

## Tests & stubbing

Tests for Query objects themselves should exercise the actual underlying query. But in other code stubbing the query
maybe desirable.

The spec helper method `stub_query(query_class, {results: ..., with: ...})` can do this for you.

It stubs `.new` on the Query object and returns instances of `CollectionBackedQuery` instead with the given `results`. 
The `with` option is passed to the Query object on initialisation and used when setting up the method stub on the 
query class.

For example:

```ruby
stub_query(TagQuery, with: {name: "Something"}, results: [t1, t2])
expect(TagQuery.new(name: "Something").first).to eql t1
```

*Note that*

This returns an instance of CollectionBackedQuery, so will not work for cases were the actual type of the query instance is
important or where you are doing a composition of queries backed by relations!

If `compose` will be used then `Quo::Query.compose` needs to be stubbed. Something might be possible to make this
nicer in future.

## Other reading

See:
* [Includes vs preload vs eager_load](http://blog.scoutapp.com/articles/2017/01/24/activerecord-includes-vs-joins-vs-preload-vs-eager_load-when-and-where)
* [Objects on Rails](http://objectsonrails.com/#sec-14)


## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add quo

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install quo

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/stevegeek/quo.

## Inspired by `rectify`

Note this implementation is loosely based on that in the `Rectify` gem; https://github.com/andypike/rectify.

See https://github.com/andypike/rectify#query-objects for more information.

Thanks to Andy Pike for the inspiration.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
