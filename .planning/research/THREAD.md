# Thread Safety Research: Ruby/Rails Thread.current Patterns

**Domain:** Thread Safety for Rails Performance Gem (CurrentRequest cleanup)
**Researched:** 2025-02-04
**Confidence:** HIGH

## Problem Statement

Rails Performance gem uses `Thread.current[:rp_current_request]` to track request context:
- Set in middleware (`lib/rails_performance/rails/middleware.rb`)
- Read in instrumentation (`lib/rails_performance/instrument/metrics_collector.rb`)
- Cleaned up after request completes

**Key Issue:** In async scenarios (Sidekiq, DelayedJob) and with thread reuse, cleanup may not be called reliably, causing data leakage between requests.

## Recommended Stack

### Core Pattern: ActiveSupport::CurrentAttributes (Rails 5.2+)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `ActiveSupport::CurrentAttributes` | Rails 5.2+ / Rails 8 | Thread-safe, fiber-safe per-request state | Rails' built-in solution with automatic cleanup via Executor callbacks |
| `ActiveSupport::IsolatedExecutionState` | Rails 8 | Internal fiber-safe state storage | Foundation for CurrentAttributes, handles both thread and fiber isolation |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **RequestStore** (legacy) | Latest | Thread-local request storage | Only if you cannot use CurrentAttributes; NOT fiber-safe |
| **request_store-fibers** | Latest | Fiber-safe RequestStore fork | Only for legacy migration on fiber-based servers (Falcon) |

## Current Implementation Analysis

### How Rails Performance Currently Uses Thread.current

**File: `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance/thread/current_request.rb`**

```ruby
def self.init
  Thread.current[:rp_current_request] ||= CurrentRequest.new(SecureRandom.hex(16))
end

def self.current
  CurrentRequest.init
end

def self.cleanup
  RailsPerformance.skip = false
  Thread.current[:rp_current_request] = nil  # Manual cleanup
end
```

**Problems identified:**
1. **Manual cleanup** - Relies on `ensure` blocks in middleware/job extensions
2. **No validation** - No check that cleanup actually occurred
3. **Thread reuse risk** - Puma/thread pools reuse threads; leaked data persists
4. **Fiber-unsafe** - `Thread.current` is fiber-local, not thread-local in Ruby 3+

### Where Cleanup is Called

**Middleware** (`lib/rails_performance/rails/middleware.rb`):
```ruby
def call!(env)
  @status, @headers, @response = @app.call(env)
  # ... save records ...
  CurrentRequest.cleanup  # Line 26
  [@status, @headers, @response]
end
```

**Sidekiq** (`lib/rails_performance/gems/sidekiq_ext.rb`):
```ruby
ensure
  record.save
  CurrentRequest.cleanup  # Line 31
end
```

**DelayedJob** (`lib/rails_performance/gems/delayed_job_ext.rb`):
```ruby
ensure
  record.save
  CurrentRequest.cleanup  # Line 28
end
```

**Risk:** If an exception occurs before `ensure`, or if middleware chain is broken, cleanup never happens.

## 2025 Best Practices for Thread.current in Rails

### Pattern 1: Use ActiveSupport::CurrentAttributes (Recommended)

**What:** Rails' built-in thread-isolated attribute singleton that resets automatically
**When:** All new Rails code; any gem tracking request-scoped state
**Why:**
- Automatic cleanup via Rails Executor callbacks
- Thread-safe and fiber-safe (Rails 8+)
- Handles both web requests and background jobs

**Example:**
```ruby
# lib/rails_performance/current.rb
module RailsPerformance
  class Current < ActiveSupport::CurrentAttributes
    attribute :request_id
    attribute :data
    attribute :tracings
    attribute :ignore
  end
end

# In middleware (before request)
RailsPerformance::Current.request_id = SecureRandom.hex(16)
RailsPerformance::Current.tracings = []
RailsPerformance::Current.ignore = Set.new

# Access anywhere (no init needed)
request_id = RailsPerformance::Current.request_id

# Cleanup happens AUTOMATICALLY via Rails Executor
# No manual cleanup required!
```

**Key advantage:** CurrentAttributes integrates with Rails Executor's `to_complete` callback, ensuring cleanup happens even with early returns or exceptions.

### Pattern 2: Rails Executor Wrapping

**What:** Explicit wrapping of code with Rails Executor for proper lifecycle management
**When:** Spawning threads manually, integrating with job processors, custom middleware

**Example from Rails Guides:**
```ruby
Thread.new do
  Rails.application.executor.wrap do
    # your code here - CurrentAttributes will be properly reset
    RailsPerformance::Current.request_id = SecureRandom.hex(16)
    # ... do work ...
  end
  # CurrentAttributes automatically cleared here
end
```

**Manual run!/complete! pattern:**
```ruby
Thread.new do
  execution_context = Rails.application.executor.run!
  # your code here
ensure
  execution_context.complete! if execution_context
end
```

### Pattern 3: Ensure Blocks with Validation

**What:** Manual cleanup with `ensure` and validation assertions
**When:** Cannot use CurrentAttributes; maintaining legacy Thread.current code
**Why:** Guarantees cleanup runs and validates it succeeded

**Example:**
```ruby
def call(env)
  init_current_request
  @status, @headers, @response = @app.call(env)
ensure
  cleanup_current_request
  validate_cleanup!  # Assert cleanup happened
end

private

def init_current_request
  Thread.current[:rp_current_request] = CurrentRequest.new(SecureRandom.hex(16))
end

def cleanup_current_request
  Thread.current[:rp_current_request] = nil
end

def validate_cleanup!
  return unless Rails.env.development? or Rails.env.test?

  if Thread.current[:rp_current_request]
    Rails.logger.error("THREAD LEAK DETECTED: CurrentRequest not cleaned up!")
    Thread.current[:rp_current_request] = nil  # Force cleanup
  end
end
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Memoization in Thread-Local Singletons

**What:** Caching values in instance variables of thread-local objects
**Why bad:** Instance variables don't reset; data leaks between requests

**From thoughtbot article (July 2025):**
```ruby
# BAD - Instance variable leaks
class Current < ActiveSupport::CurrentAttributes
  attribute :user

  def feature_flags
    @_feature_flags ||= FeatureFlags.new(user)  # Leaks!
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

**Consequences:**
- First user's data persists for all subsequent users
- Only appears under concurrent load
- Difficult to reproduce in development

### Anti-Pattern 2: Thread.current Without Ensure

**What:** Setting Thread.current values without guaranteeing cleanup
**Why bad:** Thread pools reuse threads; leaked data persists

**Bad:**
```ruby
def call(env)
  Thread.current[:request_id] = SecureRandom.hex
  @app.call(env)
  # What if exception? What if early return?
  Thread.current[:request_id] = nil  # Never reached
end
```

**Good:**
```ruby
def call(env)
  Thread.current[:request_id] = SecureRandom.hex
  @app.call(env)
ensure
  Thread.current[:request_id] = nil  # Always runs
end
```

**Better:** Use CurrentAttributes (no manual cleanup needed)

### Anti-Pattern 3: RequestStore in Fiber-Based Servers

**What:** Using RequestStore gem with Falcon or other fiber-based servers
**Why bad:** RequestStore uses Thread.current, which is fiber-local, not thread-local

**Problem:** Each fiber in the same thread gets different storage, breaking request isolation.

**Solution:** Use `request_store-fibers` gem or migrate to CurrentAttributes

## Thread Safety Patterns

### The Fiber vs Thread Distinction

**Critical concept for Ruby 3+ and Rails 8:**

| Storage Type | Scope | Ruby Behavior |
|--------------|-------|---------------|
| `Thread.current[]` | Thread-local | Actually **fiber-local** in Ruby |
| `Fiber.current[:key]` | Fiber-local | True fiber-local storage |
| `ActiveSupport::CurrentAttributes` | Execution-isolated | Handles both correctly (Rails 8+) |

**From Rails Issue #48279:**
> "The attributes get stored based on a threadlocal key, and all the fibers are in the same thread, so they're all able to read Context"

**Rails 8 solution:** `ActiveSupport::IsolatedExecutionState` automatically detects fiber vs thread context and stores appropriately.

### Thread Pool Reuse Problem

**How Puma/Sidekiq handle threads:**
1. Thread pool creates N threads at startup
2. Threads are reused for multiple requests/jobs
3. If Thread.current not cleaned up, next request gets previous data

**Example leakage scenario:**
```ruby
# Request 1 on Thread A
Thread.current[:user] = "alice@example.com"
# ... process ...
# Cleanup FAILS (exception, middleware bug)

# Request 2 on Thread A (same thread, reused)
Thread.current[:user]  # Still "alice@example.com"!
# Request 2 now thinks it's Request 1's user
```

### Mutex Synchronization Patterns

**When needed:** Sharing mutable state between threads

**From Better Stack guide (Sept 2025):**
```ruby
class SafeCounter
  def initialize
    @count = 0
    @mutex = Mutex.new
  end

  def increment
    @mutex.synchronize do
      @count += 1
    end
  end
end
```

**Note:** CurrentAttributes doesn't need mutexes - each thread/fiber has isolated storage.

## Cleanup Validation Strategies

### Strategy 1: Development Mode Assertions

**What:** Assert cleanup happened in development/test
**Why:** Catches thread leaks early in development

```ruby
# In test or development only
if Rails.env.development? || Rails.env.test?
  def validate_cleanup!
    if Thread.current[:rp_current_request]
      raise "Thread.current[:rp_current_request] not cleaned up!"
    end
  end
end
```

### Strategy 2: Monitor Thread Keys

**What:** Track all Thread.current keys and validate none leak

```ruby
# In a test
before do
  @before_keys = Thread.current.keys.dup
end

after do
  leaked_keys = Thread.current.keys - @before_keys
  assert_empty leaked_keys, "Thread keys leaked: #{leaked_keys.inspect}"
end
```

### Strategy 3: Cleanup Logging

**What:** Log every cleanup to verify it's called

```ruby
def self.cleanup
  RailsPerformance.log "CurrentRequest.cleanup called for #{Thread.current.object_id}"
  # ... actual cleanup ...
end

# In tests, assert log contains cleanup message
```

### Strategy 4: Object Finalizers (Advanced)

**What:** Use Ruby's ObjectSpace finalizer to detect leaked objects

```ruby
def self.init
  request = CurrentRequest.new(SecureRandom.hex(16))
  ObjectSpace.define_finalizer(request, proc { |id|
    Rails.logger.warn "CurrentRequest #{id} was garbage collected without cleanup!"
  })
  Thread.current[:rp_current_request] = request
end
```

**Note:** Finalizers are unreliable and have performance overhead. Use only for debugging.

## Testing Approaches for Thread Safety

### Test 1: Concurrent Request Simulation

**What:** Simulate multiple requests in parallel to detect leakage

```ruby
# test/thread_safety_test.rb
require "concurrent"

test "current request does not leak between threads" do
  threads = 10.times.map do |i|
    Thread.new do
      Rails.application.executor.wrap do
        RailsPerformance::CurrentRequest.init
        request_id = RailsPerformance::CurrentRequest.current.request_id

        # Simulate work
        sleep 0.01

        # Verify request_id hasn't changed
        assert_equal request_id, RailsPerformance::CurrentRequest.current.request_id

        RailsPerformance::CurrentRequest.cleanup
      end
    end
  end

  threads.each(&:join)

  # Verify no Thread.current data remains
  assert_nil Thread.current[:rp_current_request]
end
```

### Test 2: Sidekiq Job Context

**What:** Test cleanup in async job scenarios

```ruby
# test/sidekiq_job_test.rb
class PerformanceJobTest < ActiveJob::TestCase
  test "cleanup happens after job completion" do
    # Mock CurrentRequest.init
    RailsPerformance::CurrentRequest.stubs(:init).returns(request_mock)

    # Ensure cleanup is called
    RailsPerformance::CurrentRequest.expects(:cleanup).once

    PerformanceJob.perform_now
  end

  test "cleanup happens even when job raises" do
    RailsPerformance::CurrentRequest.stubs(:init)
    RailsPerformance::CurrentRequest.expects(:cleanup).once

    ErrorJob.perform_now  # Raises an error
  end
end
```

### Test 3: Exception Handling

**What:** Verify cleanup runs even when exceptions occur

```ruby
test "cleanup runs on exception" do
  RailsPerformance::CurrentRequest.init

  begin
    raise "boom"
  rescue
    # Exception caught
  end

  # Cleanup should have run
  assert_nil Thread.current[:rp_current_request]
end
```

### Test 4: Thread Pool Reuse

**What:** Simulate thread pool to detect data leakage

```ruby
test "data does not leak across thread reuse" do
  pool = Concurrent::ThreadPoolExecutor.new(min_threads: 1, max_threads: 1)

  # First job
  pool.post do
    Rails.application.executor.wrap do
      RailsPerformance::CurrentRequest.init
      Thread.current[:user_id] = 123
      sleep 0.01
      RailsPerformance::CurrentRequest.cleanup
    end
  end

  sleep 0.1  # Ensure first job completes

  # Second job (same thread)
  pool.post do
    Rails.application.executor.wrap do
      # Should not see leaked data
      assert_nil Thread.current[:user_id]
    end
  end

  pool.shutdown
  pool.wait_for_termination
end
```

### Test 5: Fiber Safety (Ruby 3+)

**What:** Verify fiber-local isolation

```ruby
test "fiber-local isolation" do
  RailsPerformance::CurrentRequest.init
  outer_request_id = RailsPerformance::CurrentRequest.current.request_id

  fiber = Fiber.new do
    RailsPerformance::CurrentRequest.init
    inner_request_id = RailsPerformance::CurrentRequest.current.request_id

    # Different request_id in fiber
    refute_equal outer_request_id, inner_request_id

    RailsPerformance::CurrentRequest.cleanup
  end

  fiber.resume

  # Outer request_id still valid
  assert_equal outer_request_id, RailsPerformance::CurrentRequest.current.request_id
end
```

## Version Compatibility

| Ruby | Rails | Thread.current Safety | CurrentAttributes | IsolatedExecutionState |
|------|-------|----------------------|-------------------|----------------------|
| 2.7 | 6.1 | Thread-safe only | Available | Not available |
| 3.0 | 6.1 | Thread-safe only | Available | Not available |
| 3.1+ | 7.0+ | Fiber-local gotcha | Available | Experimental |
| 3.3+ | 7.1+ | Fiber-local gotcha | Available | Available |
| 3.4+ | 8.0+ | Fiber-local gotcha | **Fiber-safe** | **Fiber-safe** |

**Key changes in Rails 8:**
- `ActiveSupport::IsolatedExecutionState` automatically handles thread vs fiber isolation
- CurrentAttributes uses IsolatedExecutionState internally
- Proper isolation for async/fiber-based servers (Falcon, async I/O)

## Migration Path for Rails Performance Gem

### Phase 1: Immediate (Add Validation)

**Add cleanup validation in development/test:**

```ruby
# lib/rails_performance/thread/current_request.rb
def self.cleanup
  RailsPerformance.skip = false
  Thread.current[:rp_current_request] = nil

  validate_cleanup! if Rails.env.development? || Rails.env.test?
end

def self.validate_cleanup!
  return unless Thread.current[:rp_current_request].nil?

  Rails.logger.warn "CurrentRequest cleanup validation failed!"
end
```

### Phase 2: Short Term (Use CurrentAttributes)

**Migrate to CurrentAttributes for automatic cleanup:**

```ruby
# lib/rails_performance/current.rb
module RailsPerformance
  class Current < ActiveSupport::CurrentAttributes
    attribute :request_id
    attribute :tracings
    attribute :ignore
    attribute :data
    attribute :record

    def self.trace(options = {})
      current.tracings << options.merge(time: RailsPerformance::Utils.time.to_i)
    end

    def self.tracings
      current.tracings ||= []
    end

    def self.ignore
      current.ignore ||= Set.new
    end
  end
end
```

**Update middleware:**
```ruby
# Remove explicit cleanup - CurrentAttributes handles it
def call!(env)
  @status, @headers, @response = @app.call(env)

  unless RailsPerformance.skip
    RailsPerformance::Models::TraceRecord.new(
      request_id: RailsPerformance::Current.request_id,
      value: RailsPerformance::Current.tracings
    ).save
  end

  # NO CLEANUP NEEDED - Rails Executor handles it

  [@status, @headers, @response]
end
```

### Phase 3: Long Term (Leverage IsolatedExecutionState)

**For Rails 8+, use IsolatedExecutionState directly if needed:**

```ruby
# Only if you need custom behavior beyond CurrentAttributes
require "active_support/isolated_execution_state"

module RailsPerformance
  class CurrentRequest
    def self.init
      ActiveSupport::IsolatedExecutionState[:rp_current_request] ||= new(SecureRandom.hex(16))
    end

    def self.current
      init
    end

    # NO CLEANUP NEEDED - automatically isolated per execution
  end
end
```

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `Thread.current[:key]` directly | Manual cleanup required; fiber-unsafe | `ActiveSupport::CurrentAttributes` |
| RequestStore gem (with fibers) | Not fiber-safe; breaks with Falcon | `request_store-fibers` or CurrentAttributes |
| Global variables (`$current_user`) | Not thread-safe at all | CurrentAttributes |
| Class variables (`@@current_user`) | Shared across all threads | CurrentAttributes |
| Instance variables in singletons | Leak between requests | CurrentAttributes attributes |

## Stack Patterns by Variant

**If Rails >= 5.2 and < 8.0:**
- Use `ActiveSupport::CurrentAttributes`
- Thread-safe, but verify fiber safety if using async/fiber libraries
- Ensure Rails Executor wraps all execution contexts

**If Rails >= 8.0:**
- Use `ActiveSupport::CurrentAttributes` (now fiber-safe)
- Or use `ActiveSupport::IsolatedExecutionState` directly for custom needs
- No manual cleanup needed

**If Rails < 5.2 or cannot use CurrentAttributes:**
- Use `Thread.current` with explicit `ensure` blocks
- Add validation in development/test
- Consider RequestStore gem (but not with fiber servers)

**If using fiber-based server (Falcon, async):**
- Must use Rails 8.0+ with CurrentAttributes
- Or use `request_store-fibers` gem
- Verify isolation under concurrent load

## Sources

### Official Documentation
- [Threading and Code Execution in Rails — Ruby on Rails Guides](https://guides.rubyonrails.org/threading_and_code_execution.html) — HIGH confidence (official Rails docs)
- [ActiveSupport::CurrentAttributes — Rails API](https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html) — HIGH confidence (official Rails API)
- [ActiveSupport::IsolatedExecutionState — Rails 8-0-stable](https://msp-greg.github.io/rails_stable/ActiveSupport/IsolatedExecutionState.html) — HIGH confidence (official Rails docs)
- [Module: ActiveSupport::IsolatedExecutionState — Rails API](https://api.rubyonrails.org/files/activesupport/lib/active_support/isolated_execution_state_rb.html) — HIGH confidence (official Rails API)
- [rails/activesupport/lib/active_support/current_attributes.rb — GitHub source](https://github.com/rails/rails/blob/main/activesupport/lib/active_support/current_attributes.rb) — HIGH confidence (official source code)

### 2025 Articles and Presentations
- [Thread Safety in Ruby and Ruby on Rails](https://kig.re/share/talks/2025-thread-safety-in-ruby-and-rails.pdf) (Feb 2025) — HIGH confidence (recent expert presentation)
- [A thread-safety gotcha with CurrentAttributes](https://thoughtbot.com/blog/a-thread-safety-gotcha-with-currentattributes) (July 15, 2025) — HIGH confidence (recent thoughtbot article on exact issue)
- [Understanding Ruby Threads and Concurrency | Better Stack](https://betterstack.com/community/guides/scaling-ruby/threads-and-concurrency/) (Sept 2025) — HIGH confidence (comprehensive guide with code examples)
- [Thread-Safe Global State in Rails with CurrentAttributes](https://medium.com/@samruddhideshpande133/thread-safe-global-state-in-rails-with-activesupport-currentattributes-6644dc087ba8) — MEDIUM confidence (verified with official docs)
- [A Complete Guide to Rails.current_attributes](https://hsps.in/post/rails-current-attributes/) (July 8, 2025) — MEDIUM confidence (comprehensive guide)

### GitHub Issues and Discussions
- [rails/rails #43773: Add IsolatedExecutionState.isolation_level](https://github.com/rails/rails/issues/43773) — HIGH confidence (official Rails repo, discusses fiber vs thread isolation)
- [rails/rails #48279: What should the behaviour of ActiveSupport::CurrentAttributes be with fibers](https://github.com/rails/rails/issues/48279) — HIGH confidence (official Rails repo, fiber safety discussion)
- [rails/rails #49227: CurrentAttributes are cleared when a job gets executed](https://github.com/rails/rails/issues/49227) — HIGH confidence (official Rails repo, async job context)
- [rails/rails #46797: Active Job async adapter connection issues](https://github.com/rails/rails/issues/46797) — HIGH confidence (official Rails repo, async connections)
- [rails/rails #55615: ActionController::Live breaks nestable ActiveSupport](https://github.com/rails/rails/issues/55615) — HIGH confidence (official Rails repo, IsolatedExecutionState clearing)

### Community and Q&A
- [Safety of Thread.current[] usage in rails — Stack Overflow](https://stackoverflow.com/questions/7896298/safety-of-thread-current-usage-in-rails) — MEDIUM confidence (Stack Overflow, verified with official docs)
- [Store thread-safe global request specific data with Rails — Stack Overflow](https://stackoverflow.com/questions/24945456/store-thread-safe-global-request-specific-data-with-rails) — MEDIUM confidence (Stack Overflow, discusses CurrentAttributes)
- [How to make sure that current_user is thread safe? — Reddit](https://www.reddit.com/r/rails/comments/16c37r0/how_to_make_sure_that_current_user_is_thread_safe/) — LOW confidence (Reddit discussion, use for community patterns only)

### Fiber and Async Specific
- [request_store-fibers gem — GitHub](https://github.com/BMorearty/request_store-fibers) — MEDIUM confidence (solution for fiber-based servers)
- [Using RequestStore with asynchronous I/O in Rails apps](https://dev.to/bmorearty/using-requeststore-with-asynchronous-io-in-rails-apps-3ma5) — MEDIUM confidence (dev.to article, fiber-specific)
- [Synchronous, Thread, and Fiber HTTP Requests in Ruby](https://blog.bbs-software.com/blog/2024/09/20/synchronous-threaded-fiber-http-requests-in-ruby/) — MEDIUM confidence (fiber vs thread comparison)
- [Your Ruby programs are always multi-threaded: Part 2](https://jpcamara.com/2024/06/23/your-ruby-programs.html) — MEDIUM confidence (article on threading, mentions CurrentAttributes)
- [Consistent, request-local state](https://jpcamara.com/2024/06/27/consistent-requestlocal-state.html) — MEDIUM confidence (fiber safety discussion)
- [RequestStore gem — GitHub](https://github.com/steveklabnik/request_store) — MEDIUM confidence (legacy alternative)
- [Storage is still thread-local — Issue #39](https://github.com/steveklabnik/request_store/issues/39) — MEDIUM confidence (discusses RequestStore limitations)

### Concurrency and Synchronization
- [Thread Safety with Mutexes in Ruby — GoRails](https://gorails.com/episodes/thread-safety-with-mutexes-in-ruby) — MEDIUM confidence (video tutorial on mutexes)
- [Never cared much about Thread-safety in Ruby when I should have](https://evgeniydemin.medium.com/never-cared-much-about-thread-safety-in-ruby-when-i-should-have-121c39d89f32) — LOW confidence (Medium article, anecdotal)
- [Finding concurrency problems in core ruby libraries — Slideshare](https://www.slideshare.net/slideshow/finding-concurrency-problems-in-core-ruby-libraries/58382155) — MEDIUM confidence (presentation slides)

### Testing Resources
- [Testing Rails Applications — Rails Guides](https://guides.rubyonrails.org/testing.html) — HIGH confidence (official Rails testing guide)
- [Locks and testing parallel transactions — BigBinary Academy](https://courses.bigbinaryacademy.com/learn-rubyonrails/locks-and-testing-parallel-transactions/) — MEDIUM confidence (parallel transaction testing)

---
*Thread safety research for: Rails Performance gem CurrentRequest cleanup*
*Researched: 2025-02-04*
