# Coding Conventions

**Analysis Date:** 2026-02-04

## Naming Patterns

**Files:**
- Snake case for all files: `base_record.rb`, `rails_performance_controller.rb`
- Modules use Pascal case: `RailsPerformance`, `Models`, `Reports`
- Classes use Pascal case: `BaseRecord`, `RequestsReport`
- Test files use snake case with `_test` suffix: `base_record_test.rb`, `rails_performance_controller_test.rb`

**Functions:**
- Methods use snake case: `calculate_data`, `nullify_data`, `setup_db`
- Getter/setter methods follow Rails conventions: `mattr_accessor`, `mattr_reader`
- Private methods prefixed with underscore: `_resource_monitor`, `_running_mode`

**Variables:**
- Local variables use snake case: `now`, `stop`, `current`
- Instance variables use snake case with `@` prefix: `@db`, `@group`, `@data`
- Class variables use snake case with `@@` prefix: `@@redis`, `@@duration`
- Constants use screaming snake case: `DEFAULT_TIME_OFFSET`, `FORMAT`

**Types:**
- Modules are namespaced under RailsPerformance: `RailsPerformance::Models::BaseRecord`
- Module structure follows logical grouping: Models, Reports, Widgets, Extensions

## Code Style

**Formatting:**
- Uses Standard Ruby formatter (`gem 'standard'`)
- Ruby 3.2 target version
- Frozen string literals enabled at top of files: `# frozen_string_literal: true`
- 2 space indentation
- No trailing whitespace

**Linting:**
- Standard Ruby linter configured
- RuboCop target Ruby version 3.2
- Linting integrated into test suite via Rake

## Import Organization

**Order:**
1. Standard library imports (top)
2. Gem imports (middle)
3. Relative imports (bottom)
4. Module declarations

**Path Aliases:**
- Uses `require_relative` for local file references
- Explicit relative paths: `require_relative 'rails_performance/version'`
- No path aliases configured

## Error Handling

**Patterns:**
- Uses `assert_nothing_raised` for testing error conditions
- Graceful handling of nil/blank values with `.presence` and nil checks
- JSON parsing with rescue for malformed data
- Logging with debug checks before execution

**Logging:**
- Centralized log method in `RailsPerformance.log`
- Debug only logging with guard clause: `return unless RailsPerformance.debug`
- Uses Rails.logger if available, falls back to puts

## Comments

**When to Comment:**
- Complex business logic (e.g., time calculations in reports)
- Configuration explanations (e.g., mattr_accessor comments)
- TODO items for future improvements
- Method signatures for complex interfaces

**RDoc/Comments:**
- Limited RDoc usage in codebase
- Comments primarily inline rather than formal documentation
- TODO comments indicate technical debt areas

## Function Design

**Size:**
- Methods generally focused on single responsibility
- Report methods handle data transformation and collection
- Base classes provide abstract interfaces with NotImplementedError
- Private helper methods used for repeated logic

**Parameters:**
- Keyword arguments used for clarity: `group: nil, sort: nil, title: nil`
- Default values provided for optional parameters
- Named parameters in test setup methods

**Return Values:**
- Consistent return patterns: arrays for collections, nil for empty states
- Objects respond to consistent interface methods
- Boolean flags for enable/disable patterns

## Module Design

**Exports:**
- Single module entry point: `RailsPerformance`
- Module methods use `mattr_accessor` for configuration
- Namespaced classes under modules: `RailsPerformance::Models`
- Mixins for extensions: `RailsPerformance.extend CustomExtension`

**Barrel Files:**
- Main library file (`rails_performance.rb`) serves as barrel file
- Requires all core components
- Provides interface through module extension

## Testing Conventions

**Test Structure:**
- Test classes inherit from appropriate base: `ActionDispatch::IntegrationTest`, `ActiveSupport::TestCase`
- Setup methods use `setup do` block
- Test methods prefixed with `test_`
- Helper methods defined in test_helper.rb

**Test Data:**
- Factory functions for common test data: `dummy_event`, `dummy_sidekiq_event`
- Reset functions for cleanup: `reset_redis`
- Setup functions for common scenarios: `setup_db`, `setup_sidekiq_db`

**Assertions:**
- Rails-style assertions: `assert_response`, `assert_equal`, `assert_nil`
- Custom assertions for specific data patterns
- Exception testing with `assert_nothing_raised`

---

*Convention analysis: 2026-02-04*