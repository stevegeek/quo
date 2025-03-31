# Quo Development Guide

## Build & Test Commands
- Run all tests: `bundle exec rake test`
- Run a single test: `bundle exec ruby -Ilib:test test/path/to/test_file.rb -n test_method_name`
- Run tests across Rails versions: `bundle exec appraisal rake test`
- Type checking: `bundle exec steep check`
- Lint code: `bundle exec standardrb`
- Fix lint issues: `bundle exec standardrb --fix`

## Code Style Guidelines
- **Frozen String Literals**: Include `# frozen_string_literal: true` at the top of every file
- **Types**: Use RBS for type annotations with `# rbs_inline: enabled` and `@rbs` annotations
- **Naming**: Use snake_case for methods/variables, CamelCase for classes, and SCREAMING_CASE for constants
- **Error Handling**: Raise specific errors with clear messages
- **Indentation**: 2 spaces (default Standard Ruby style)
- **Testing**: Use Minitest for tests
- **Framework**: Built on Literal gem - use Literal::Struct and Literal::Types
- **Documentation**: Document public methods with comments