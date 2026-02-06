# Phase 2: Thread Safety with CurrentAttributes - Research

**Researched:** 2026-02-06
**Domain:** Rails Thread Safety, ActiveSupport::CurrentAttributes, Background Job Integration
**Confidence:** HIGH

## Summary

This phase migrates RailsPerformance from manual Thread.current-based cleanup to Rails' built-in ActiveSupport::CurrentAttributes for automatic, reliable cleanup via Rails Executor. The current implementation uses `Thread.current[:rp_current_request]` which requires manual cleanup calls in middleware, Sidekiq, DelayedJob, Rake, and Grape extensions. This manual approach is error-prone and can leak data between requests when cleanup fails or exceptions occur.

**Primary recommendation:** Create `RailsPerformance::Current < ActiveSupport::CurrentAttributes` with the same attributes as CurrentRequest, migrate all consumers to use Current instead, then remove CurrentRequest and all manual cleanup calls. Add development-mode validation to detect any remaining Thread.current usage. Leverage Rails Executor's automatic reset mechanism via ActionDispatch::Executor middleware for web requests and ensure proper wrapping for background jobs.

The migration follows a "big bang" approach: add Current (deprecated alias to CurrentRequest), migrate consumers, verify functionality, then remove CurrentRequest. CurrentAttributes has been available since Rails 5.2 (released 2018) and works consistently through Rails 8.1. The gem's existing Appraisals already tests Rails 7.2, 8.0, and 8.1, so adding 5.2, 6.1, and 7.0/7.1 representative versions will confirm compatibility.

## User Constraints (from CONTEXT.md)

### Locked Decisions

1. **Migration approach**: Big bang migration — Create Current, migrate everything, then remove CurrentRequest. Single deployment, brief cutover.
2. **CurrentRequest class**: Deprecate first (keep as deprecated alias for one version), then remove in follow-up
3. **Manual cleanup calls**: Remove only after Current is verified working — safety net retained during transition
4. **User upgrade process**: Multiple steps (Add Current → Migrate consumers → Remove cleanup)
5. **Current attributes design**: Keep all existing CurrentRequest attributes: `request_id`, `tracings`, `ignore` (read-only); `data`, `record` (read-write)
6. **Naming**: Preserve camelCase naming — `Current.request_id` (not `current.request_id`) for compatibility
7. **Class definition**: `RailsPerformance::Current extends ActiveSupport::CurrentAttributes`
8. **Validation strategy**: Development-mode validation with warnings only (non-disruptive feedback)
9. **Environment scope**: Development + test environments (not production)
10. **Detection method**: Pattern matching for `Thread.current[:rp_current_request]` — targeted, fewer false positives
11. **Rails version support**: Unified CurrentAttributes implementation across Rails 5.2 through 8.0
12. **CI testing**: Test representative versions (5.2, 6.1, 7.2, 8.0) rather than all versions
13. **Minimum Rails**: Require Rails 5.2+ (CurrentAttributes availability), no shims for older versions

### Claude's Discretion

1. Exact deprecation message wording for CurrentRequest
2. Whether to add configurable flag to enable/disable validation warnings
3. Specific new attributes to add to Current (deferred to planning)
4. Test matrix details for representative Rails versions

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ActiveSupport::CurrentAttributes` | Rails 5.2+ / Rails 8.0+ | Thread-safe, fiber-safe per-request state with automatic cleanup | Rails' built-in solution for request-scoped state; integrates with Rails Executor for automatic reset via ActionDispatch::Executor middleware |
| `ActiveSupport::IsolatedExecutionState` | Rails 7.1+ / Rails 8.0+ | Internal fiber-safe state storage | Foundation for CurrentAttributes; handles both thread and fiber isolation automatically |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Sidekiq::CurrentAttributes` middleware | Sidekiq 6.3+ | Automatic CurrentAttributes serialization into jobs | Already built into Sidekiq; serializes Current attributes so they flow from web requests into background jobs |
| `Rails.application.executor` | Rails 5.2+ | Execution context wrapping for proper lifecycle | Use when spawning threads manually or integrating with job processors that don't auto-wrap |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `ActiveSupport::CurrentAttributes` | `Thread.current` with manual `ensure` blocks | Manual cleanup is error-prone; data leaks when exceptions occur; requires validation infrastructure |
| `ActiveSupport::CurrentAttributes` | `RequestStore` gem | RequestStore uses Thread.current internally, so it has the same fiber-unsafety issues in Ruby 3+; CurrentAttributes is Rails' official solution |
| `ActiveSupport::CurrentAttributes` | `request_store-fibers` gem | Fork for fiber-based servers (Falcon); CurrentAttributes (Rails 8+) handles this natively |

**Installation:**
No additional gems needed. ActiveSupport::CurrentAttributes is part of ActiveSupport which is already a dependency via `railties`.

## Architecture Patterns

### Recommended Project Structure

```
lib/rails_performance/
├── current.rb                    # NEW: RailsPerformance::Current < ActiveSupport::CurrentAttributes
├── thread/
│   ├── current_request.rb        # EXISTING: To be deprecated and removed
│   └── current_request_monitor.rb # NEW: Development-mode Thread.current leak detector
├── rails/
│   └── middleware.rb             # MODIFY: Remove CurrentRequest.cleanup calls
├── gems/
│   ├── sidekiq_ext.rb           # MODIFY: Remove CurrentRequest.cleanup calls
│   ├── delayed_job_ext.rb       # MODIFY: Remove CurrentRequest.cleanup calls
│   ├── rake_ext.rb              # MODIFY: Remove CurrentRequest.cleanup calls
│   └── grape_ext.rb             # MODIFY: Remove CurrentRequest.cleanup calls
└── instrument/
    └── metrics_collector.rb     # MODIFY: Use Current instead of CurrentRequest
```

### Pattern 1: ActiveSupport::CurrentAttributes for Request State

**What:** Create a thread-isolated attributes singleton that resets automatically before and after each request/job via Rails Executor.

**When to use:** All new Rails code; any gem tracking request-scoped state; migrating from Thread.current patterns.

**Why:** Automatic cleanup via Rails Executor callbacks (`to_run` and `to_complete`); thread-safe and fiber-safe (Rails 8+); no manual cleanup needed.

**Example:**
```ruby
# lib/rails_performance/current.rb
# Source: https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html
module RailsPerformance
  class Current < ActiveSupport::CurrentAttributes
    attribute :request_id
    attribute :tracings
    attribute :ignore
    attribute :data
    attribute :record

    # Convenience method for tracing
    def self.trace(options = {})
      current.tracings << options.merge(time: RailsPerformance::Utils.time.to_i)
    end

    # Initialize defaults on first access
    def self.tracings
      current.tracings ||= []
    end

    def self.ignore
      current.ignore ||= Set.new
    end
  end
end
```

**Usage throughout codebase:**
```ruby
# In middleware (before request)
RailsPerformance::Current.request_id = SecureRandom.hex(16)
RailsPerformance::Current.tracings = []
RailsPerformance::Current.ignore = Set.new

# Access anywhere (no init needed)
request_id = RailsPerformance::Current.request_id

# Store data
RailsPerformance::Current.data = { controller: "PostsController", action: "index" }

# Cleanup happens AUTOMATICALLY via Rails Executor
# No manual cleanup required!
```

### Pattern 2: Migration with Deprecated Alias (Big Bang Approach)

**What:** Create Current as the new implementation, keep CurrentRequest as a deprecated alias pointing to Current during transition period.

**When to use:** Migrating existing gems with public APIs; single-deployment cutover strategy.

**Why:** Maintains backward compatibility during transition; allows gradual migration of consumers; safety net (CurrentRequest still works) until verification complete.

**Example:**
```ruby
# lib/rails_performance/current.rb
module RailsPerformance
  class Current < ActiveSupport::CurrentAttributes
    attribute :request_id
    attribute :tracings
    attribute :ignore
    attribute :data
    attribute :record

    # ... methods from Pattern 1 ...
  end
end

# lib/rails_performance/thread/current_request.rb
# DEPRECATED: Use RailsPerformance::Current instead
module RailsPerformance
  class CurrentRequest
    def self.init
      # Initialize Current for backward compatibility
      Current.request_id ||= SecureRandom.hex(16)
      Current.tracings ||= []
      Current.ignore ||= Set.new
    end

    def self.current
      # Delegate to Current
      ActiveSupport::Deprecation.warn(
        "CurrentRequest.current is deprecated. Use RailsPerformance::Current instead.",
        caller_locations(1)
      )
      OpenStruct.new(
        request_id: Current.request_id,
        tracings: Current.tracings,
        ignore: Current.ignore,
        data: Current.data,
        record: Current.record
      )
    end

    def self.cleanup
      # No-op - CurrentAttributes handles cleanup automatically
      ActiveSupport::Deprecation.warn(
        "CurrentRequest.cleanup is deprecated. CurrentAttributes resets automatically via Rails Executor.",
        caller_locations(1)
      )
    end

    # ... other methods delegating to Current ...
  end
end
```

### Pattern 3: Development-Mode Thread Leak Detection

**What:** Add validation in development/test mode to detect Thread.current[:rp_current_request] usage after migration.

**When to use:** Migrating from Thread.current to CurrentAttributes; want to catch any missed manual cleanup or lingering Thread.current usage.

**Why:** Catches data leaks early in development; non-disruptive (warnings only); helps verify migration success.

**Example:**
```ruby
# lib/rails_performance/thread/current_request_monitor.rb
module RailsPerformance
  class CurrentRequestMonitor
    def self.check_for_leaks!
      return unless Rails.env.development? || Rails.env.test?

      if Thread.current[:rp_current_request]
        Rails.logger.warn(
          "THREAD LEAK DETECTED: Thread.current[:rp_current_request] still set after request/job. " \
          "This indicates CurrentRequest.cleanup was not called or Thread.current is being used directly. " \
          "Please migrate to RailsPerformance::Current for automatic cleanup."
        )
        # Optionally: force cleanup to prevent actual data leakage in dev
        Thread.current[:rp_current_request] = nil
      end
    end
  end
end

# In middleware (after request, only in dev/test)
if Rails.env.development? || Rails.env.test?
  RailsPerformance::CurrentRequestMonitor.check_for_leaks!
end
```

### Pattern 4: Sidekiq Integration (Automatic via Sidekiq Middleware)

**What:** Sidekiq 6.3+ includes built-in CurrentAttributes middleware that automatically serializes attributes into jobs.

**When to use:** Using Sidekiq for background jobs; want request context to flow into jobs.

**Why:** Zero configuration for most use cases; attributes serialize automatically; no manual job argument passing needed.

**Example:**
```ruby
# Sidekiq handles this automatically - no changes needed!
# CurrentAttributes set in web request flow into job:

# In controller action
RailsPerformance::Current.request_id = SecureRandom.hex(16)
MyJob.perform_later  # Current.request_id automatically serialized into job

# In job
class MyJob < ApplicationJob
  def perform
    # Current.request_id is automatically restored here!
    puts "Processing job with request_id: #{RailsPerformance::Current.request_id}"
  end
end

# After job completes, CurrentAttributes automatically reset via Rails Executor
```

**For custom Sidekiq middleware (rails_performance's existing SidekiqExt):**
```ruby
# lib/rails_performance/gems/sidekiq_ext.rb
# BEFORE (with manual cleanup):
def call(worker, msg, queue)
  # ... setup ...
  begin
    result = yield
  ensure
    record.save
    CurrentRequest.cleanup  # Manual cleanup - can be removed!
  end
end

# AFTER (with CurrentAttributes):
def call(worker, msg, queue)
  # ... setup ...
  begin
    result = yield
  ensure
    record.save
    # NO CLEANUP NEEDED - CurrentAttributes resets automatically
  end
end
```

### Pattern 5: DelayedJob Integration (Manual Executor Wrapping)

**What:** DelayedJob does not auto-wrap with Rails Executor, so manual wrapping may be needed for proper CurrentAttributes reset.

**When to use:** Using DelayedJob for background jobs; want CurrentAttributes to reset properly after jobs.

**Why:** Ensures CurrentAttributes lifecycle matches job execution; prevents data leakage between jobs.

**Example:**
```ruby
# lib/rails_performance/gems/delayed_job_ext.rb
# BEFORE (with manual cleanup):
class Plugin < ::Delayed::Plugin
  callbacks do |lifecycle|
    lifecycle.around(:invoke_job) do |job, *args, &block|
      now = RailsPerformance::Utils.time
      block.call(job, *args)
    ensure
      record.save
      CurrentRequest.cleanup  # Manual cleanup - can be removed!
    end
  end
end

# AFTER (with CurrentAttributes - if DelayedJob doesn't wrap with Executor):
class Plugin < ::Delayed::Plugin
  callbacks do |lifecycle|
    lifecycle.around(:invoke_job) do |job, *args, &block|
      # Wrap with Rails Executor for automatic CurrentAttributes reset
      Rails.application.executor.wrap do
        now = RailsPerformance::Utils.time
        block.call(job, *args)
      ensure
        record.save
        # NO CLEANUP NEEDED - Executor handles it
      end
    end
  end
end

# OR if DelayedJob already wraps with Executor (verify in testing):
class Plugin < ::Delayed::Plugin
  callbacks do |lifecycle|
    lifecycle.around(:invoke_job) do |job, *args, &block|
      now = RailsPerformance::Utils.time
      block.call(job, *args)
    ensure
      record.save
      # NO CLEANUP NEEDED - Executor handles it
    end
  end
end
```

**Note:** Verify DelayedJob's Executor wrapping in testing. Some versions may already wrap; if so, no manual wrapping needed.

### Pattern 6: Rake Task Integration (Executor Wrapping)

**What:** Rake tasks need explicit Rails Executor wrapping for proper CurrentAttributes lifecycle.

**When to use:** Instrumenting Rake tasks with performance tracking; want automatic cleanup.

**Why:** Rake tasks don't automatically use Rails Executor; manual wrapping ensures CurrentAttributes reset after task.

**Example:**
```ruby
# lib/rails_performance/gems/rake_ext.rb
# BEFORE (with manual cleanup):
def invoke_with_rails_performance(*args)
  now = RailsPerformance::Utils.time
  status = 'success'
  invoke_without_new_rails_performance(*args)
rescue Exception => e
  status = 'error'
  raise(e)
ensure
  unless RailsPerformance.skipable_rake_tasks.include?(name)
    record = RailsPerformance::Models::RakeRecord.new(
      task: task_info,
      datetime: now.strftime(RailsPerformance::FORMAT),
      datetimei: now.to_i,
      duration: (RailsPerformance::Utils.time - now) * 1000,
      status: status
    )
    record.save
    CurrentRequest.cleanup  # Manual cleanup - can be removed!
  end
end

# AFTER (with CurrentAttributes):
def invoke_with_rails_performance(*args)
  # Wrap with Rails Executor for automatic CurrentAttributes reset
  Rails.application.executor.wrap do
    now = RailsPerformance::Utils.time
    status = 'success'
    invoke_without_new_rails_performance(*args)
  rescue Exception => e
    status = 'error'
    raise(e)
  ensure
    unless RailsPerformance.skipable_rake_tasks.include?(name)
      record = RailsPerformance::Models::RakeRecord.new(
        task: task_info,
        datetime: now.strftime(RailsPerformance::FORMAT),
        datetimei: now.to_i,
        duration: (RailsPerformance::Utils.time - now) * 1000,
        status: status
      )
      record.save
      # NO CLEANUP NEEDED - Executor handles it
    end
  end
end
```

### Pattern 7: Grape API Integration (No Changes Needed)

**What:** Grape API middleware uses ActiveSupport::Notifications and existing Rails middleware stack.

**When to use:** Instrumenting Grape API endpoints with rails_performance.

**Why:** Grape runs through Rails middleware stack, so ActionDispatch::Executor handles CurrentAttributes reset automatically.

**Example:**
```ruby
# lib/rails_performance/gems/grape_ext.rb
# BEFORE (with manual cleanup):
ActiveSupport::Notifications.subscribe(/grape/) do |name, start, finish, _id, payload|
  CurrentRequest.current.ignore.add(:performance)
  # ... collect metrics ...
  if name == 'format_response.grape'
    CurrentRequest.current.record.save
    CurrentRequest.cleanup  # Manual cleanup - can be removed!
  end
end

# AFTER (with CurrentAttributes):
ActiveSupport::Notifications.subscribe(/grape/) do |name, start, finish, _id, payload|
  RailsPerformance::Current.ignore.add(:performance)
  # ... collect metrics ...
  if name == 'format_response.grape'
    RailsPerformance::Current.record.save
    # NO CLEANUP NEEDED - Rails Executor handles it via middleware stack
  end
end
```

### Anti-Patterns to Avoid

- **Don't use instance variables in CurrentAttributes:** They leak between requests. Always use `attribute` for state.
- **Don't call `Current.reset` manually:** Rails Executor handles this. Manual calls can cause double-reset issues.
- **Don't use reserved attribute names:** Rails 7.1+ prohibits `set`, `reset`, `resets`, `instance`, `before_reset`, `after_reset`, `reset_all`, `clear_all` as attribute names.
- **Don't skip Rails Executor wrapping:** For background jobs and Rake tasks that don't auto-wrap, always use `Rails.application.executor.wrap`.
- **Don't deprecate prematurely:** Keep CurrentRequest working until Current is verified in production.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Thread-local request storage | Custom Thread.current management with `ensure` blocks | `ActiveSupport::CurrentAttributes` | Manual cleanup is error-prone; Rails Executor integration is complex; fiber-safety (Ruby 3+) requires IsolatedExecutionState |
| Development-mode leak detection | Custom validation logic sprinkled everywhere | Single `CurrentRequestMonitor.check_for_leaks!` called in middleware/development | Centralized validation is easier to maintain; can be disabled via config; consistent warning messages |
| Background job context propagation | Pass request_id as job argument manually | Sidekiq's built-in CurrentAttributes middleware | Automatic serialization; no changes to job signatures; works with any attribute type that's serializable |
| Thread-safe initialization | Custom mutex-based singleton initialization | CurrentAttributes' built-in `instance` method | Rails already handles thread-safe singleton creation; `IsolatedExecutionState` handles fiber-safety in Rails 8+ |

**Key insight:** Rails has solved thread-safe per-request state management with CurrentAttributes and Rails Executor. Building custom Thread.current management is reinventing the wheel and getting the edge cases wrong (fiber safety, executor integration, exception handling).

## Common Pitfalls

### Pitfall 1: Removing Cleanup Before Verification

**What goes wrong:** Removing all `CurrentRequest.cleanup` calls before verifying CurrentAttributes works correctly, leading to data leaks if CurrentAttributes isn't properly integrated.

**Why it happens:** Excitement to clean up old code; overconfidence in automatic mechanisms; insufficient testing.

**How to avoid:**
1. Keep CurrentRequest and cleanup calls during initial Current implementation
2. Add deprecation warnings to CurrentRequest methods
3. Test thoroughly in development with multiple concurrent requests
4. Verify CurrentAttributes reset happens via Rails Executor (check logs, add debug output)
5. Only remove CurrentRequest after seeing CurrentAttributes work correctly in production for a while

**Warning signs:**
- Seeing same request_id across different requests in logs
- Tests failing with "Current.request_id is nil" errors
- User data mixing between requests (security issue!)

### Pitfall 2: Reserved Attribute Names in Rails 7.1+

**What goes wrong:** Using `set`, `reset`, or other reserved names as CurrentAttributes attributes causes `ArgumentError: Restricted attribute names` in Rails 7.1+.

**Why it happens:** CurrentAttributes uses these names internally; Rails 7.1 added validation to prevent conflicts.

**How to avoid:**
- Check attribute names against Rails 7.1+ reserved list: `set`, `reset`, `resets`, `instance`, `before_reset`, `after_reset`, `reset_all`, `clear_all`
- Current attributes from CurrentRequest are safe: `request_id`, `tracings`, `ignore`, `data`, `record`
- If adding new attributes, avoid reserved names or add version checks

**Warning signs:**
- `ArgumentError: Restricted attribute names: set, reset` on Rails 7.1+
- Test suite passes on Rails 7.2 but fails on 7.1

### Pitfall 3: Missing Rails Executor Wrapping for Background Jobs

**What goes wrong:** CurrentAttributes not resetting after DelayedJob or Rake tasks, causing data leakage between jobs/tasks.

**Why it happens:** These execution contexts don't automatically wrap with Rails Executor like web requests do.

**How to avoid:**
- Always wrap background job execution with `Rails.application.executor.wrap { ... }`
- Test by setting Current attributes in one job/task and verifying they're nil in the next
- Add logging to verify Current.reset happens after each job/task

**Warning signs:**
- Same request_id appearing across different background job executions
- Tests passing individually but failing when run in sequence
- User A's data appearing in User B's job context

### Pitfall 4: Instance Variable Leaks in CurrentAttributes

**What goes wrong:** Using instance variables in CurrentAttributes class methods causes data to persist between requests.

**Why it happens:** CurrentAttributes instance is reused; instance variables don't reset automatically.

**How to avoid:**
- Never use `@foo` in class methods; always use `attribute :foo` and access via `Current.foo`
- If you need computed state, compute it from attributes or store in an attribute itself

**Example:**
```ruby
# BAD - Instance variable leaks!
class Current < ActiveSupport::CurrentAttributes
  attribute :user

  def feature_flags
    @feature_flags ||= FeatureFlags.new(user)  # Leaks!
  end
end

# GOOD - Use attribute
class Current < ActiveSupport::CurrentAttributes
  attribute :feature_flags
  attribute :user
end

# Set explicitly where needed
Current.feature_flags = FeatureFlags.new(Current.user)
```

**Warning signs:**
- First user's data persisting for all subsequent users
- Only appears under concurrent load
- Difficult to reproduce in development (single-threaded)

### Pitfall 5: Testing Without Rails Executor

**What goes wrong:** Tests don't wrap execution with Rails Executor, so CurrentAttributes doesn't reset between tests, causing flaky test suites.

**Why it happens:** Minitest/test-unit doesn't auto-wrap like Rails controller tests do; RSpec has special handling.

**How to avoid:**
- Use `Rails.application.executor.wrap` in test setup/teardown
- For Minitest, add to `test_helper.rb`:
  ```ruby
  module ActiveSupport::TestCase
    setup do
      Rails.application.executor.run!
    end

    teardown do
      Rails.application.executor.complete!
    end
  end
  ```
- Verify Current attributes are nil at test start and end

**Warning signs:**
- Tests pass individually but fail when run in suite
- Intermittent test failures with "Current.request_id already set" errors
- Test data from one test appearing in another

### Pitfall 6: Fiber Unsafety in Ruby 3+ (Pre-Rails 8)

**What goes wrong:** Using CurrentAttributes (Rails 5.2-7.x) with fiber-based servers like Falcon causes data to leak between fibers.

**Why it happens:** `Thread.current` is actually fiber-local in Ruby 3+, so each fiber in same thread gets different storage.

**How to avoid:**
- For Rails < 8 with fiber servers: Use `request_store-fibers` gem or avoid CurrentAttributes
- For Rails 8+: CurrentAttributes is fiber-safe via IsolatedExecutionState
- Test with actual fiber-based server if supporting that use case

**Warning signs:**
- Data mixing between requests on Falcon
- Request A seeing Request B's Current attributes
- Only happens under async/concurrent load

### Pitfall 7: Sidekiq Middleware Conflict

**What goes wrong:** Custom Sidekiq middleware conflicts with Sidekiq's built-in CurrentAttributes middleware, causing double-serialization or missing attributes.

**Why it happens:** Sidekiq 6.3+ auto-includes `Sidekiq::CurrentAttributes` middleware; custom middleware may interfere.

**How to avoid:**
- Check if `Sidekiq::CurrentAttributes` middleware is already present
- Use Sidekiq's middleware API to insert custom middleware in correct position
- Test that attributes flow correctly from web requests into jobs

**Warning signs:**
- Current attributes nil in jobs even though set in web request
- Jobs failing with "Current not initialized" errors
- Double serialization warnings in Sidekiq logs

### Pitfall 8: Breaking Changes During Deprecation Period

**What goes wrong:** Changing CurrentRequest API during deprecation period breaks user code that hasn't migrated yet.

**Why it happens:** Treating deprecated code as "dead" and making breaking changes before users have migrated.

**How to avoid:**
- Keep CurrentRequest fully functional until removed entirely
- Only add deprecation warnings, don't change behavior
- Use `ActiveSupport::Deprecation` for consistent warnings
- Communicate deprecation timeline clearly in changelog

**Warning signs:**
- User reports of "CurrentRequest not working" after upgrade
- Breaking changes in minor version (should only happen in major)
- Changelog doesn't mention deprecation

## Code Examples

Verified patterns from official sources:

### Creating CurrentAttributes Class

```ruby
# Source: https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html
module RailsPerformance
  class Current < ActiveSupport::CurrentAttributes
    attribute :request_id
    attribute :tracings
    attribute :ignore
    attribute :data
    attribute :record
  end
end
```

### Setting and Accessing Attributes

```ruby
# Source: https://guides.rubyonrails.org/threading_and_code_execution.html
# In controller/middleware before request
RailsPerformance::Current.request_id = SecureRandom.hex(16)
RailsPerformance::Current.tracings = []
RailsPerformance::Current.ignore = Set.new

# Access anywhere in application
request_id = RailsPerformance::Current.request_id
tracings = RailsPerformance::Current.tracings

# Modify read-write attributes
RailsPerformance::Current.data = { controller: "PostsController", action: "index" }
RailsPerformance::Current.record = RailsPerformance::Models::RequestRecord.new(...)
```

### Custom Methods on CurrentAttributes

```ruby
# Source: https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html
module RailsPerformance
  class Current < ActiveSupport::CurrentAttributes
    attribute :tracings

    def self.trace(options = {})
      current.tracings << options.merge(time: RailsPerformance::Utils.time.to_i)
    end
  end
end

# Usage
RailsPerformance::Current.trace(group: :db, duration: 5.2, sql: "SELECT * FROM users")
```

### Rails Executor Wrapping for Background Jobs

```ruby
# Source: https://guides.rubyonrails.org/threading_and_code_execution.html
# For background jobs that don't auto-wrap with Executor
Rails.application.executor.wrap do
  # Your code here - CurrentAttributes will be properly reset
  RailsPerformance::Current.request_id = SecureRandom.hex(16)
  # ... do work ...
end
# CurrentAttributes automatically cleared here
```

### Sidekiq CurrentAttributes Serialization

```ruby
# Source: https://github.com/mperham/sidekiq/blob/main/lib/sidekiq/middleware/current_attributes.rb
# Sidekiq handles this automatically - no code needed!

# In web request
RailsPerformance::Current.request_id = SecureRandom.hex(16)
MyJob.perform_later

# In job (request_id automatically available)
class MyJob < ApplicationJob
  def perform
    puts "Request ID: #{RailsPerformance::Current.request_id}"
  end
end
```

### Development-Mode Validation

```ruby
# Source: Based on pattern from THREAD.md research
module RailsPerformance
  class CurrentRequestMonitor
    def self.check_for_leaks!
      return unless Rails.env.development? || Rails.env.test?

      if Thread.current[:rp_current_request]
        Rails.logger.warn(
          "THREAD LEAK DETECTED: Thread.current[:rp_current_request] still set. " \
          "Use RailsPerformance::Current for automatic cleanup."
        )
        Thread.current[:rp_current_request] = nil
      end
    end
  end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Thread.current[:key]` with manual cleanup | `ActiveSupport::CurrentAttributes` with automatic reset via Rails Executor | Rails 5.2 (April 2018) | Eliminates entire class of data leakage bugs; no more manual cleanup |
| Thread-local only (Ruby 2.x) | Fiber-safe execution isolation (Ruby 3+ with Rails 8) | Rails 8.0 (November 2024) | Proper isolation for async/fiber-based servers (Falcon, async I/O) |
| Manual job argument passing for context | Sidekiq CurrentAttributes middleware auto-serialization | Sidekiq 6.3 (October 2020) | Request context flows automatically into background jobs |
| No validation of Thread.current cleanup | Development-mode leak detection | Community best practice (2024-2025) | Catches data leaks early in development cycle |

**Deprecated/outdated:**
- **RequestStore gem** (not fiber-safe in Ruby 3+): Use `ActiveSupport::CurrentAttributes` instead
- **Manual Thread.current cleanup** with `ensure` blocks: CurrentAttributes handles this via Rails Executor
- **Custom thread-local singletons**: CurrentAttributes is the Rails-standard approach
- **`request_store-fibers` gem** (for fiber-based servers): Rails 8+ CurrentAttributes handles this natively

## Open Questions

1. **DelayedJob Executor Wrapping Status**
   - **What we know:** DelayedJob may or may not auto-wrap with Rails Executor depending on version/configuration
   - **What's unclear:** Whether existing DelayedJob installations already have Executor wrapping
   - **Recommendation:** Test both scenarios (with and without explicit wrapping) in Phase 2; add conditional wrapping if needed; document findings

2. **Exact CI Test Matrix for Rails Versions**
   - **What we know:** Existing Appraisals covers Rails 7.2, 8.0, 8.1; gemspec requires `railties` but no minimum version specified
   - **What's unclear:** Which specific versions to add for comprehensive coverage (5.2, 6.0, 6.1, 7.0, 7.1?)
   - **Recommendation:** Add representative versions based on adoption: 5.2 (first with CurrentAttributes), 6.1 (LTS), 7.2 (current stable), 8.0 (current major). Skip 6.0, 7.0, 7.1 for CI speed but document manual testing.

3. **Configurable Validation Warnings**
   - **What we know:** Development-mode validation is non-disruptive (warnings only)
   - **What's unclear:** Whether users want ability to disable validation via config
   - **Recommendation:** Start with simple always-on validation in dev/test; add config option if users request it; don't over-engineer upfront

4. **Sidekiq Middleware Interaction**
   - **What we know:** Sidekiq 6.3+ includes CurrentAttributes middleware that auto-serializes attributes
   - **What's unclear:** Whether rails_performance's custom SidekiqExt middleware conflicts with built-in middleware
   - **Recommendation:** Test Sidekiq integration thoroughly; verify middleware order; document any required configuration

## Sources

### Primary (HIGH confidence)

- [ActiveSupport::CurrentAttributes — Rails API Documentation](https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html) — Official Rails API docs for CurrentAttributes API, attributes, callbacks
- [Threading and Code Execution in Rails — Ruby on Rails Guides](https://guides.rubyonrails.org/threading_and_code_execution.html) — Official Rails guide on Executor, wrapping code for proper lifecycle management
- [ActiveSupport::CurrentAttributes — Rails 5.2.1 API](https://api.rubyonrails.org/v5.2.1/classes/ActiveSupport/CurrentAttributes.html) — Rails 5.2 API docs confirming CurrentAttributes availability in Rails 5.2
- [ActiveSupport::CurrentAttributes — Rails 7.1.0 API](https://api.rubyonrails.org/v7.1.0/classes/ActiveSupport/CurrentAttributes.html) — Rails 7.1 API docs showing reserved attribute names restriction
- [ActiveSupport::ExecutionWrapper — Rails 8.1.2 API](https://api.rubyonrails.org/v8.1.2/classes/ActiveSupport/ExecutionWrapper.html) — Rails Executor implementation details for Rails 8
- [rails/activesupport/lib/active_support/current_attributes.rb — GitHub source](https://github.com/rails/rails/blob/main/activesupport/lib/active_support/current_attributes.rb) — Official CurrentAttributes source code showing implementation
- [sidekiq/lib/sidekiq/middleware/current_attributes.rb — GitHub source](https://github.com/mperham/sidekiq/blob/main/lib/sidekiq/middleware/current_attributes.rb) — Sidekiq's built-in CurrentAttributes middleware source

### Secondary (MEDIUM confidence)

- [A thread-safety gotcha with CurrentAttributes — thoughtbot](https://thoughtbot.com/blog/a-thread-safety-gotcha-with-currentattributes) — July 2025 article on instance variable leaks in CurrentAttributes (verified against official docs)
- [Thread Safety in Ruby and Ruby on Rails — kig.re](https://kig.re/share/talks/2025-thread-safety-in-ruby-and-rails.pdf) — February 2025 presentation on thread safety patterns (verified examples against Rails guides)
- [Understanding Ruby Threads and Concurrency — Better Stack](https://betterstack.com/community/guides/scaling-ruby/threads-and-concurrency/) — September 2025 comprehensive guide (verified code examples)
- [A Complete Guide to Rails.current_attributes](https://hsps.in/post/rails-current-attributes/) — July 2025 guide with usage examples (verified against official API)
- [Sidekiq and Request-Specific Context — Mike Perham](https://www.mikeperham.com/2022/07/29/sidekiq-and-request-specific-context/) — Sidekiq creator's article on CurrentAttributes integration
- [Middleware and CurrentAttributes — Sidekiq Issue #4568](https://github.com/sidekiq/sidekiq/issues/4568) — GitHub discussion on Sidekiq CurrentAttributes middleware
- [RSpec does not reset ActiveSupport::CurrentAttributes — Issue #2503](https://github.com/rspec/rspec-rails/issues/2503) — RSpec-rails issue on CurrentAttributes reset in tests
- [Resetting ActiveSupport::CurrentAttributes — Issue #2773](https://github.com/rspec/rspec-rails/issues/2773) — RSpec-rails discussion on test isolation

### Tertiary (LOW confidence)

- [Thread-Safe Global State in Rails with ActiveSupport — Medium](https://medium.com/@samruddhideshpande133/thread-safe-global-state-in-rails-with-activesupport-currentattributes-6644dc087ba8) — Community article (verified concepts against official docs)
- [Safety of Thread.current[] usage in rails — Stack Overflow](https://stackoverflow.com/questions/7896298/safety-of-thread-current-usage-in-rails) — Community Q&A discussion
- [request_store-fibers gem — GitHub](https://github.com/BMorearty/request_store-fibers) — Solution for fiber-based servers (verified use case)
- [ActiveRecord: Understanding CurrentAttributes — Mintbit](https://www.mintbit.com/blog/activerecord-understanding-currentattributes/) — January 2026 article on CurrentAttributes patterns

## Metadata

**Confidence breakdown:**
- **Standard stack:** HIGH — CurrentAttributes is Rails' official solution since 5.2; well-documented in official guides
- **Architecture:** HIGH — Patterns verified against official Rails API docs and guides; Sidekiq middleware source code reviewed
- **Pitfalls:** MEDIUM — Most pitfalls documented in official sources; some edge cases (fiber safety in Rails < 8) based on community articles
- **Rails version compatibility:** HIGH — Availability confirmed via official API docs for 5.2, 7.1, 8.0; existing Appraisals file shows 7.2, 8.0, 8.1 tested

**Research date:** 2026-02-06

**Valid until:** 2026-05-06 (90 days) — CurrentAttributes API is stable (Rails 5.2-8.x), but Rails 9 may introduce changes in late 2026

**Researcher notes:**
- Sidekiq integration is particularly well-supported via built-in middleware (less custom code needed than expected)
- DelayedJob requires verification of Executor wrapping status (open question #1)
- Rails 7.1's reserved attribute names restriction is a new gotcha that didn't exist in earlier versions
- Fiber safety is fully solved in Rails 8+, so emphasize Rails 8+ for async/fiber-based servers
- Development-mode validation is straightforward pattern matching (no complex infrastructure needed)
