## [Unreleased]


## [1.0.0.rc1] - Unreleased

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
