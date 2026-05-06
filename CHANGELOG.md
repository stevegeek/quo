## [Unreleased]

## [1.0.0] - 2026-05-06

First stable release. Folds in the perf work and tooling shipped in beta3.

### Added

- **Claude Code skill bundled with the gem.** A skill at `claude-skill/`
  teaches Claude Code how to build composable, type-safe query objects
  with Quo. The skill's `SKILL.md` covers the most important Quo concept
  to get right — class-vs-instance composition, when to use each, and the
  performance trade-offs involved. Reference files in
  `claude-skill/references/` go deep on query types, composition, pagination,
  transformers, and the API surface.
- **Rails install generator.** `bin/rails generate quo:install` copies the
  bundled skill into the host app's `.claude/skills/quo/` directory.
  Re-running with `--force` refreshes the skill after a Quo upgrade.
  Optional `--with-claude-md` opt-in appends a short pointer to the
  project's top-level `CLAUDE.md`. The fragment is idempotent — safe to
  re-run.

## [1.0.0.beta3] - 2026-05-06

### Performance

Composition is materially cheaper. Constructing and resolving a composed query
no longer reallocates per-call infrastructure that the Ruby/Literal class
hierarchy already provides for free. On a representative composition graph
(four-level tree, 16 page-renders), measured improvements over `1.0.0.beta2`:

- ~46% lower wall-clock time
- ~51% less time spent in GC
- ~38% fewer total allocations

No public API changes. The wins come from five internal fixes:

- `Quo::Composing` now reuses singleton class- and instance-strategy
  registries instead of allocating fresh ones on every `composer` /
  `merge_instances` call.
- The class-level helpers on composed query classes (`_composing_joins`,
  `_left_query`, `inspect`, `quo_operand_desc`, etc.) live on a new
  `Quo::ComposedQuery::ClassMethods` module that is `extend`ed via the
  `included` hook, rather than being re-defined inside the per-class
  `Class.new { class << self; ... end }` block.
- `Quo::Composing::ClassStrategy#collect_properties` now skips properties
  that the composed class's chosen superclass already declares — Literal
  inherits these automatically, and re-registering them on every anonymous
  class did a full `Literal::Property` allocation, schema dup, and
  `module_eval` for no behavioural gain. This is the dominant win.
- `Quo::RelationBackedQuery#respond_to_missing?` now reuses the memoized
  `RelationBackedQuerySpecification.blank` singleton instead of allocating
  a fresh specification on every probe (ActiveRecord's delegation chain
  hits `respond_to?` heavily).
- `Quo::ComposedQuery#left` / `#right` now pass `_specification:` to the
  child constructor directly. Previously they always allocated the child
  via `.new`, then allocated a second copy via `.with_specification(...)`
  (which calls `copy(...)`), even when the specification was `nil`.

## [1.0.0.beta2] - 2025-04-01

### Breaking Changes

- `Quo::ComposedQuery.composer` is now `Quo::Composing.composer`
- `Quo::ComposedQuery.merge_instances` is now `Quo::Composing.merge_instances`

### Fixed

- Fixed issue with handling of query specifications in the query composer

## [1.0.0.beta1] - 2025-04-01

### Breaking Changes

Nearly everything has had changes. Porting will require some effort.

- Quo now depends on `literal`, meaning attributes (options) to queries are typed and explicit
- Composing query objects now allows you to compose query classes rather than just instances of query objects
- `MergedQuery`, `EagerQuery` & `LoadedQuery` have been removed
- `Query` is now an abstract base class for `RelationBackedQuery` and `CollectionBackedQuery`
- The API of `Query` has been reduced/simplified significantly
- `Query` classes only build queries, to actually execute/take actions on them you need to call `#results` and get a `Results` object
- `preload`ing behaviour is now a separate concern from `Query` and is handled by `Preloadable` module.
- Drop support for Ruby <= 3.1 and Rails < 7.0
- Gem is now a Rails engine and relies on autoloading

### Changed

- Update docs, dependencies, and tests
- Use appraisals for testing

### Added

- Helpers `stub_query` and `mock_query` for Minitest
- Support for Rails 8

## [0.5.0] - 2022-12-23

### Changed

- Merged and Wrapped queries should not have factory methods as they are not meant to be constructed directly
- Create new LoadedQuery which separates the concern of "preloaded" Query from EagerQuery which represents a query which is loaded and memoized

## [0.4.0] - 2022-12-23

### Changed

- Some redundant nil checks (either safe navigation operator or conditionals) to make type check pass
- Fix for type of transform method which takes optional index as second arg 
- group_by can take a block
- Change last and first methods to just take a limit value
- Add new configuration options for page size limit and default and fix typing for enumerable
- Rename Enumerator to Results and Query#enumerator to #results
- Change EagerQuery initializer to take collection as positional param

## [0.3.1] - 2022-12-22

### Changed

- Convenience methods on Query
- Implement group_by on enumerator to transform values in resulting groups
- Add WrappedQuery instead of Query taking a scope param
- Change `initialize` method of MergedQuery

## [0.3.0] - 2022-12-20

### Changed

- Make `joins` on compose a kwarg

## [0.2.0] - 2022-12-20

### Added

- Railtie for rake task
- Rake task which hackily looks for qo in the app and displays a list
- Prepare to add RBS types

### Changed

- Gem deps
- Query interface

### Added

- Test suite and dummy rails app
- Add Enumerator

## [0.1.0] - 2022-11-18

- Initial release
