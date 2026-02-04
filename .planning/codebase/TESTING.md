# Testing Patterns

**Analysis Date:** 2026-02-04

## Test Framework

**Runner:**
- Minitest with Rails integration
- Test files located in `test/` directory
- Pattern: `test/**/*_test.rb`
- Rails test tasks loaded via `rails/test_help`

**Assertion Library:**
- Built-in Minitest assertions
- Rails-specific assertions for integration tests
- Custom helper methods in test_helper.rb

**Run Commands:**
```bash
rake test              # Run all tests
rake standard          # Run linter
rake                  # Run both (default)
```

## Test File Organization

**Location:**
- Co-located with source files: `test/` mirrors `lib/` and `app/` structure
- Engine tests in `test/` root
- Dummy app in `test/dummy/` for full Rails environment

**Naming:**
- Test files mirror source file names: `utils_test.rb` for `utils.rb`
- Controller tests follow Rails conventions: `rails_performance_controller_test.rb`
- Suffix: `_test.rb`

**Structure:**
```
test/
├── test_helper.rb          # Test setup and helpers
├── base_record_test.rb     # Model tests
├── rails_performance_controller_test.rb  # Controller tests
├── utils_test.rb           # Utility tests
├── duration_test.rb        # Feature tests
├── events_test.rb          # Feature tests
└── test/dummy/            # Dummy Rails app for integration
```

## Test Structure

**Suite Organization:**
```ruby
class RailsPerformanceControllerTest < ActionDispatch::IntegrationTest
  setup do
    reset_redis
    RailsPerformance.skip = false
    # Setup data
  end

  test 'should get home page' do
    # Test implementation
  end
end
```

**Patterns:**
- Setup blocks for common test preparation
- Test names describe expected behavior
- Integration tests for controllers
- Unit tests for models and utilities

**Test Types:**
- Unit tests: Single class/method testing
- Integration tests: Controller endpoints and workflows
- Feature tests: Cross-cutting functionality

## Mocking

**Framework:**
- No external mocking framework detected
- Uses Ruby's built-in testing capabilities
- Stubbing via Minitest's built-in features

**Patterns:**
```ruby
# Configuration testing
original_config = RailsPerformance.ignored_endpoints
RailsPerformance.ignored_endpoints = ['HomeController#contact']
# Test code
RailsPerformance.ignored_endpoints = original_config

# Exception testing
begin
  get '/account/site/crash'
rescue StandardError
end
```

**What to Mock:**
- Configuration values
- Redis interactions
- Time-based calculations
- External service calls

**What NOT to Mock:**
- ActiveRecord models
- Rails controller behavior
- HTTP response handling
- Built-in Ruby methods

## Fixtures and Factories

**Test Data:**
```ruby
def dummy_event(time: RailsPerformance::Utils.time, controller: 'Home', action: 'index', status: 200, path: '/',
                method: 'GET', request_id: SecureRandom.hex(16))
  RailsPerformance::Models::RequestRecord.new(
    controller: controller,
    action: action,
    format: 'html',
    status: status,
    datetime: time.strftime(RailsPerformance::FORMAT),
    datetimei: time.to_i,
    method: method,
    path: path,
    view_runtime: rand(100.0),
    db_runtime: rand(100.0),
    duration: 100 + rand(100.0),
    request_id: request_id
  )
end
```

**Location:**
- Factory methods defined in `test_helper.rb`
- Helper functions for common test scenarios
- No YAML fixtures detected

## Coverage

**Requirements:**
- SimpleCov configured
- Coverage excludes test/dummy directory
- Minimum coverage not enforced

**View Coverage:**
```bash
open coverage/index.html
```

## Test Types

**Unit Tests:**
- Focus on single class/method behavior
- Examples: `BaseRecordTest`, `UtilsTest`
- Isolated with custom data creation
- Test specific business logic

**Integration Tests:**
- Test controller endpoints and workflows
- Examples: `RailsPerformanceControllerTest`
- Use HTTP requests via `get`, `post`, etc.
- Test response status and content

**Feature Tests:**
- Test cross-cutting functionality
- Examples: `DurationTest`, `EventsTest`
- Test real-world scenarios
- May span multiple components

## Common Patterns

**Async Testing:**
- Limited async testing patterns detected
- Focus on synchronous request/response cycles
- Time-based testing via controlled data

**Error Testing:**
```ruby
test 'should get crashes with params' do
  begin
    get '/account/site/crash'
  rescue StandardError
  end

  get '/rails/performance/crashes'
  assert_response :success
  assert response.body.include?('Account::SiteController')
end
```

**Configuration Testing:**
```ruby
test 'should respect ignored_endpoints configuration value' do
  original_ignored_endpoints = RailsPerformance.ignored_endpoints
  RailsPerformance.ignored_endpoints = ['HomeController#contact']
  # Test behavior
  RailsPerformance.ignored_endpoints = original_ignored_endpoints
end
```

**Data Setup:**
```ruby
def setup_db(event = dummy_event)
  event.save
end

def setup_sidekiq_db(event = dummy_sidekiq_event)
  event.save
end
```

**CSV Export Testing:**
```ruby
test 'crashes CSV export' do
  # Setup crash data
  get '/rails/performance/crashes.csv'
  assert_response :success
  assert_equal 'text/csv', response.content_type
  assert_includes response.body, 'controller'
end
```

## Test Organization Best Practices

**Setup/Teardown:**
- Centralized setup in `setup` blocks
- Redis cleanup between tests
- Configuration restoration after modification

**Test Isolation:**
- Each test is independent
- No shared test state
- Proper cleanup after tests

**Naming Conventions:**
- Descriptive test names starting with "should"
- Focus on behavior rather than implementation
- Clear and specific assertions

**Data Management:**
- Factory functions for consistent test data
- Randomization to avoid test collisions
- Proper seeding for realistic scenarios

---

*Testing analysis: 2026-02-04*