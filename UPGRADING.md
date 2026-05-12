# Upgrading Quo

## Upgrading from 1.x to 2.0

Quo 2.0 is a structural rework of query composition. Most code continues
to work unchanged. There are two intentional behavioural changes worth
knowing about before you bump, plus a new value-form API you'll want to
adopt for hot paths.

### TL;DR

- Composition still uses `+` / `compose` / `merge`. Same API.
- **Class composition** (`SomeClass + OtherClass`) — unchanged. Returns a Class.
- **Instance composition** (`some_instance + other_instance`) — now returns a
  concrete value (`Quo::ComposedRelationBackedQuery` or
  `Quo::ComposedCollectionBackedQuery`), not an anonymous class. Allocates
  no new classes per call.
- New: `Quo::RelationBackedQuery.from(relation)` and
  `Quo::CollectionBackedQuery.from(enumerable)` — value-form constructors,
  for use instead of `wrap(rel).new` on hot paths.
- 1.x's "prop fan-out from a synthesised parent class" is gone. Each
  operand keeps its own constructor-time props. Two subtle consequences
  documented below.
- ~2× faster instance composition, with **zero anonymous classes per call**.

### Why

1.x had a single composition path. Both `Q1 + Q2` (between classes) and
`q1 + q2` (between instances) went through the same machinery, which
allocated a fresh anonymous class on every call. For instances, the
class was then immediately instantiated once and discarded — pure
waste, paid per request.

2.0 splits the two cases. Class composition keeps the class-allocation
machinery (it's the right shape for *defining a new type* once at
code-load time). Instance composition produces a value instead — a
small struct that holds the two operands and walks them at unwrap
time. No anonymous classes, no `prop` re-registration.

### What's the same

- The `+` / `compose` / `merge` API at both class and instance levels.
- The leaf query class API: `prop`, `query`, `collection`, `transform`,
  `wrap`, `with_specification`, etc.
- Pagination and transformer surfaces on every Quo::Query.
- Specifications (`order(...)`, `joins(...)`, `where(...)`, `distinct`,
  etc.) on relation-backed queries, including when applied to a composed
  instance.
- `Quo::ComposedQuery` is still the marker module used by class
  composition. Existing `kind_of?(Quo::ComposedQuery)` checks on
  class-composed results keep working.
- Composed and wrapped value-form instances are subclasses of the
  configured base classes (`Quo.relation_backed_query_base_class`,
  `Quo.collection_backed_query_base_class` — typically
  `ApplicationRelationQuery` / `ApplicationCollectionQuery`). Anything
  defined on those base classes is available on `.from`-constructed and
  instance-composed values. The base classes are resolved at autoload
  time, so configure `Quo.relation_backed_query_base_class_name = ...`
  in an initializer (it runs before eager load / first reference in
  Rails apps).

### What's intentionally different

#### 1. Prop fan-out at instance composition is gone

In 1.x, `(Q1.new(score: 0.5) + Q2.new(score: 0.7))` produced a merged
class whose effective `score` was 0.7 (right won) and that value was
fanned to every child at unwrap time.

In 2.x, each operand keeps its own constructor-time props. The merged
relation is the AND of both operands' filters, evaluated independently:

```ruby
# 1.x: filter = (score < 0.7 AND score < 0.7)  -> score < 0.7
# 2.x: filter = (score < 0.5 AND score < 0.7)  -> score < 0.5
```

If you relied on 1.x's "right wins everywhere" behaviour, you now need
to construct the leaf with the value you actually want:

```ruby
# Equivalent to 1.x's behaviour
Q1.new(score: 0.7) + Q2.new(score: 0.7)
```

#### 2. Pagination inherits as a coupled (page, page_size) pair

In 1.x, `page` and `page_size` were fanned independently, so a composed
query could end up with `page: 2` from the left operand and
`page_size: 50` from the right, even though neither operand was
constructed with that pair.

In 2.x, pagination inherits *as a unit* from whichever operand is
paginated (i.e. has a non-nil `page`). Right wins if both are.
`page_size` alone doesn't make a query paginated, because every
Quo::Query has a default `page_size`.

If you previously relied on the cross-pollination behaviour, set
pagination explicitly on the composed instance:

```ruby
(q1 + q2).copy(page: 1, page_size: 50).results
```

### What's new

#### `.from` — value-form constructors

For wrapping a bare relation or enumerable as a Quo::Query at a call
site, use `.from` instead of `wrap(...).new`:

```ruby
# 1.x — still works, but allocates a new class per call.
Quo::RelationBackedQuery.wrap(Comment.where(read: false)).new.results

# 2.x — value form, no Class.new per call.
Quo::RelationBackedQuery.from(Comment.where(read: false)).results

# Same for collections.
Quo::CollectionBackedQuery.from([1, 2, 3]).results
```

`.from` returns an instance of `Quo::WrappedRelationBackedQuery` /
`Quo::WrappedCollectionBackedQuery`. They behave like any other
Quo::Query — composable, paginatable, transformable.

Keep using `wrap` when you want a *class* (constant assignment, block
form with typed props):

```ruby
# Still right in 2.x — type-defining use.
RecentComments = Quo::RelationBackedQuery.wrap(props: {since: Time}) do
  Comment.where("created_at > ?", since)
end
RecentComments.new(since: 1.day.ago).results
```

The skill bundled with Quo (`bin/rails generate quo:install`) covers
the class-vs-instance composition cut and the new `.from` API.

### Performance

Measured on a representative 3-leaf instance composition (5000
iterations of `(L.new + R.new + T.new).unwrap.to_sql`):

| metric              | 1.0.0       | 2.0.0       | Δ           |
|---------------------|-------------|-------------|-------------|
| wall                | 3805 ms     | 1740 ms     | 2.2× faster |
| GC time             | 238 ms      | 61 ms       | 4× less     |
| total allocations   | 8,000,091   | 4,755,036   | -41%        |
| T_CLASS allocations | 753         | **0**       | -100%       |

The "zero T_CLASS per call" is the structural win — instance
composition no longer goes through `Class.new`.

### Migrating

For most apps, just bumping the gem version and running tests is
sufficient. If tests fail, they'll fall into one of these categories:

1. **Test asserted 1.x's prop-fan-out "right wins at unwrap time".**
   Update the test to reflect the new behaviour (filter is the AND of
   each operand's own filter) or restructure your call site to
   construct each leaf with the values you want.

2. **Test asserted the cross-pollinated pagination behaviour.** Set
   pagination explicitly on the composed instance, not at the leaf
   level.

3. **Test calls `composed.copy(some_user_prop:)` and expects a single
   prop value to be observed.** v2's copy applies the new value to
   every operand that declares the prop (right-wins precedence on
   reads when both have it). Behaviour matches if you wanted "this
   value, everywhere". If you wanted "this value on one side only",
   construct the new operand explicitly: `q.copy(_left: q._left.copy(prop: x))`.

### Performance opportunities

After upgrading, scan for these patterns and consider rewriting:

- `Quo::RelationBackedQuery.wrap(some_relation).new` → use
  `Quo::RelationBackedQuery.from(some_relation)`.
- `(Q1 + Q2).new(prop: value)` at a call site → if `Q1` and `Q2` are
  classes, this still allocates a new class per request. Either hoist
  the composition to a constant (`MyType = Q1 + Q2`) and instantiate
  `MyType.new(...)` per request, or switch to instance composition
  (`Q1.new(prop: value) + Q2.new(...)` ).

Both patterns are clearly explained in the bundled skill — see
`.claude/skills/quo/SKILL.md` after running `bin/rails generate quo:install`.
