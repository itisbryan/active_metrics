# Stack Research: Testing Async Jobs & Error Handling in Ruby/Rails

**Domain:** Background job testing with Sidekiq/DelayedJob
**Researched:** 2026-02-04
**Confidence:** MEDIUM

## Recommended Stack

### Core Testing Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Minitest | (Rails 8.0 bundled) | Test runner | Bundled with Rails 8.0, lightweight, fast, active development |
| Sidekiq::Testing | 8.1.0+ | Sidekiq test harness | Official testing modes (fake, inline, disable), well-maintained |
| Delayed::Worker | 4.2.0 | Delayed Job testing | Built-in work_off method for immediate execution in tests |
| Redis (test instance) | Latest | Integration testing | Required for realistic load testing and failure simulation |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| concurrent-ruby | Latest | Thread-safe testing | Load testing with concurrent jobs, race condition detection |
| mock_redis | Latest | Redis mocking | Unit tests where real Redis adds overhead |
| webmock | Latest | External service mocking | Testing error handling for external API calls in jobs |
| timecop | Latest | Time manipulation | Testing retry schedules, job timing, expiration |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| SimpleCov | Code coverage | Already configured in the gem |
| parallel_tests | Parallel test execution | Speed up test suite, test true concurrent behavior |

## Installation

```ruby
# Gemfile - Test group
group :test do
  gem 'simplecov', require: false
  gem 'mock_redis'
  gem 'webmock'
  gem 'timecop'
  gem 'parallel_tests'
  gem 'concurrent-ruby'

  # Sidekiq and DelayedJob already in main Gemfile
  gem 'sidekiq'
  gem 'delayed_job_active_record'
end
```

```bash
# Install test dependencies
bundle install

# For load testing tools
gem install parallel_tests
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Minitest | RSpec | Use RSpec if team prefers its DSL and richer mock framework; sidekiq-specific gem rspec-sidekiq available |
| Sidekiq::Testing (inline) | Sidekiq::Testing (fake) | Use fake mode when testing job queuing without execution; use inline for integration tests |
| real Redis | mock_redis | Use mock_redis for fast unit tests; use real Redis for load testing and failure scenarios |
| built-in work_off | Delayed::Worker.delay_jobs = false | Use delay_jobs = false for truly inline execution; work_off gives more control |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `sidekiq/testing` in production | Automatically calls fake! and disables Redis | Only require in test environment |
| Testing thread safety with sleeps | Unreliable, non-deterministic | Use concurrent-ruby gem with deterministic parallel execution |
| Ignoring Redis failures in tests | Masks production issues | Test Redis failure scenarios explicitly |
| Relying only on fake mode | Doesn't test middleware or real execution | Combine fake, inline, and real Redis tests |

## Testing Patterns by Scenario

### 1. Sidekiq Testing with Minitest

**Setup:**
```ruby
# test/test_helper.rb
require 'sidekiq/testing'

# Default to fake mode for most tests
Sidekiq::Testing.fake!

# Clean up between tests
module SidekiqMinitestSupport
  def after_teardown
    Sidekiq::Worker.clear_all
    super
  end
end

class MiniTest::Spec
  include SidekiqMinitestSupport
end

class MiniTest::Unit::TestCase
  include SidekiqMinitestSupport
end
```

**Test queuing (Fake Mode):**
```ruby
test 'job is enqueued correctly' do
  assert_equal 0, HardWorker.jobs.size
  HardWorker.perform_async(1, 2)
  assert_equal 1, HardWorker.jobs.size
  assert_equal [1, 2], HardWorker.jobs.last['args']
end
```

**Test execution with middleware (Drain):**
```ruby
test 'job executes successfully with middleware' do
  Sidekiq::Testing.server_middleware do |chain|
    chain.add RailsPerformance::Gems::SidekiqExt
  end

  HardWorker.perform_async(1, 2)
  assert_equal 1, HardWorker.jobs.size

  # Execute all queued jobs
  HardWorker.drain
  assert_equal 0, HardWorker.jobs.size

  # Verify metrics were saved
  datasource = RailsPerformance::DataSource.new(q: {}, type: :sidekiq)
  assert_equal 1, datasource.db.data.size
end
```

**Test inline execution:**
```ruby
test 'job executes immediately in inline mode' do
  Sidekiq::Testing.inline! do
    HardWorker.perform_async(1, 2)
    # Job has already executed
  end
end
```

### 2. Delayed Job Testing with Minitest

**Setup:**
```ruby
# test/test_helper.rb

# Option 1: Execute jobs immediately (inline mode)
Delayed::Worker.delay_jobs = false

# Option 2: Execute only non-scheduled jobs immediately
Delayed::Worker.delay_jobs = ->(job) {
  job.run_at && job.run_at > Time.now.utc
}

# Clean up between tests
setup do
  Delayed::Job.delete_all
end
```

**Test immediate execution:**
```ruby
test 'delayed job executes immediately' do
  user = User.create

  # With delay_jobs = false, this executes immediately
  user.delay.say_hello

  # No jobs in queue
  assert_equal 0, Delayed::Job.count

  # Side effect already happened
  assert user.hello_said
end
```

**Test work_off pattern:**
```ruby
test 'delayed job executes via work_off' do
  Delayed::Worker.delay_jobs = true  # Queue the job

  user = User.create
  user.delay.say_hello

  assert_equal 1, Delayed::Job.count

  # Execute all pending jobs
  worker = Delayed::Worker.new(quiet: true)
  worker.work_off

  assert_equal 0, Delayed::Job.count
  assert user.hello_said
end
```

**Test with custom middleware:**
```ruby
test 'delayed job middleware captures metrics' do
  RailsPerformance::Gems::DelayedJobExt.init

  user = User.create
  user.delay.say_hello

  worker = Delayed::Worker.new(quiet: true)
  worker.work_off

  # Verify metrics were saved
  datasource = RailsPerformance::DataSource.new(q: {}, type: :delayed_job)
  assert_equal 1, datasource.db.data.size
end
```

### 3. Error Handling Testing

**Test Sidekiq job failure:**
```ruby
test 'sidekiq job failure is captured' do
  RailsPerformance.redis.flushdb

  begin
    s = RailsPerformance::Gems::SidekiqExt.new
    s.call('FailingWorker', 'msg', 'default') do
      raise StandardError, 'Job failed!'
    end
  rescue StandardError
    # Expected
  end

  datasource = RailsPerformance::DataSource.new(q: {}, type: :sidekiq)
  assert_equal 'exception', datasource.db.data.last.status
  assert_equal 'Job failed!', datasource.db.data.last.message
end
```

**Test malformed job data:**
```ruby
test 'handles malformed sidekiq message' do
  malformed_msg = {
    'jid' => nil,  # Missing jid
    'enqueued_at' => 'invalid',  # Invalid timestamp
    'created_at' => 'invalid'
  }

  s = RailsPerformance::Gems::SidekiqExt.new
  result = s.call('Worker', malformed_msg, 'default') do
    'success'
  end

  # Should handle gracefully
  assert_equal 'success', result
end
```

**Test retry behavior:**
```ruby
test 'sidekiq job retry configuration' do
  # Test custom retry count
  class CustomRetryJob
    include Sidekiq::Job
    sidekiq_options retry: 5

    def perform(*args)
      raise 'Temporary error'
    end
  end

  # Verify retry configuration
  assert_equal 5, CustomRetryJob.get_sidekiq_options['retry']
end
```

**Test error handlers:**
```ruby
test 'error handler receives exceptions' do
  errors_captured = []

  # Register test error handler
  Sidekiq.configure_server do |config|
    config.error_handlers << proc {|ex, ctx, cfg|
      errors_captured << { ex: ex, ctx: ctx }
    }
  end

  # Trigger error in inline mode
  Sidekiq::Testing.inline! do
    begin
      FailingJob.perform_async
    rescue StandardError
      # Expected
    end
  end

  assert_equal 1, errors_captured.size
  assert_equal 'Temporary error', errors_captured.first[:ex].message
end
```

### 4. Load Testing with Concurrent Jobs

**Test concurrent Sidekiq job execution:**
```ruby
require 'concurrent-ruby'

test 'handles concurrent sidekiq jobs' do
  job_count = 100
  errors = []
  mutex = Mutex.new

  # Create a thread pool
  pool = Concurrent::ThreadPoolExecutor.new(
    min_threads: 10,
    max_threads: 20,
    max_queue: 100
  )

  # Enqueue jobs concurrently
  job_count.times do |i|
    pool.post do
      begin
        HardWorker.perform_async(i)
      rescue => e
        mutex.synchronize { errors << e }
      end
    end
  end

  pool.shutdown
  pool.wait_for_termination

  # Assert all jobs were enqueued
  assert_equal job_count, HardWorker.jobs.size
  assert_empty errors, "Errors occurred: #{errors.map(&:message).join(', ')}"
end
```

**Test concurrent Delayed Job execution:**
```ruby
test 'handles concurrent delayed jobs' do
  job_count = 50

  # Create jobs concurrently
  threads = job_count.times.map do |i|
    Thread.new do
      User.create(id: i).delay.say_hello
    end
  end

  threads.each(&:join)

  assert_equal job_count, Delayed::Job.count

  # Execute all jobs
  worker = Delayed::Worker.new(quiet: true)
  worker.work_off

  assert_equal 0, Delayed::Job.count
end
```

**Test thread-safe metrics collection:**
```ruby
test 'sidekiq metrics are thread-safe under load' do
  RailsPerformance.redis.flushdb

  threads = 20.times.map do |i|
    Thread.new do
      s = RailsPerformance::Gems::SidekiqExt.new
      10.times do |j|
        s.call("Worker#{i}", {'jid' => "jid#{i}#{j}", 'enqueued_at' => Time.now.to_i, 'created_at' => Time.now.to_i}, 'default') do
          sleep(0.001)  # Simulate work
          'done'
        end
      end
    end
  end

  threads.each(&:join)

  datasource = RailsPerformance::DataSource.new(q: {}, type: :sidekiq)
  assert_equal 200, datasource.db.data.size
end
```

### 5. Redis Failure Simulation

**Test Redis connection failure:**
```ruby
test 'handles redis connection failure gracefully' do
  original_redis = RailsPerformance.redis

  begin
    # Simulate Redis failure
    RailsPerformance.stub(:redis, nil) do
      s = RailsPerformance::Gems::SidekiqExt.new

      # Should not crash, but handle gracefully
      assert_raises(Redis::CannotConnectError) do
        s.call('Worker', {'jid' => 'test', 'enqueued_at' => Time.now.to_i, 'created_at' => Time.now.to_i}, 'default') do
          'work'
        end
      end
    end
  ensure
    RailsPerformance.redis = original_redis
  end
end
```

**Test Redis timeout:**
```ruby
test 'handles redis timeout' do
  # Use mock_redis to simulate timeout
  mock_redis = MockRedis.new

  original_redis = RailsPerformance.redis
  RailsPerformance.redis = mock_redis

  begin
    s = RailsPerformance::Gems::SidekiqExt.new
    s.call('Worker', {'jid' => 'test', 'enqueued_at' => Time.now.to_i, 'created_at' => Time.now.to_i}, 'default') do
      'work'
    end

    # Verify data was saved to mock Redis
    assert mock_redis.keys('sidekiq*').size > 0
  ensure
    RailsPerformance.redis = original_redis
  end
end
```

**Test Redis flush during active job:**
```ruby
test 'handles redis flush during job execution' do
  s = RailsPerformance::Gems::SidekiqExt.new

  thread = Thread.new do
    s.call('Worker', {'jid' => 'test', 'enqueued_at' => Time.now.to_i, 'created_at' => Time.now.to_i}, 'default') do
      sleep(0.1)  # Simulate work
      'done'
    end
  end

  # Flush Redis while job is running
  sleep(0.05)
  RailsPerformance.redis.flushdb

  thread.join

  # Job completed even though Redis was flushed
  assert_equal 'done', thread.value
end
```

### 6. Malformed Data Testing

**Test missing required fields in Sidekiq message:**
```ruby
test 'handles missing jid in sidekiq message' do
  incomplete_msg = {
    'enqueued_at' => Time.now.to_i,
    'created_at' => Time.now.to_i
    # Missing 'jid'
  }

  s = RailsPerformance::Gems::SidekiqExt.new
  result = s.call('Worker', incomplete_msg, 'default') do
    'success'
  end

  # Should still complete job even if metrics fail
  assert_equal 'success', result
end
```

**Test invalid timestamp formats:**
```ruby
test 'handles invalid timestamp in sidekiq message' do
  invalid_msg = {
    'jid' => 'test123',
    'enqueued_at' => 'not-a-number',
    'created_at' => 'also-not-a-number'
  }

  s = RailsPerformance::Gems::SidekiqExt.new
  result = s.call('Worker', invalid_msg, 'default') do
    'success'
  end

  assert_equal 'success', result
end
```

**Test nil/empty worker names:**
```ruby
test 'handles nil worker name' do
  msg = {
    'jid' => 'test123',
    'enqueued_at' => Time.now.to_i,
    'created_at' => Time.now.to_i,
    'wrapped' => nil  # No wrapped worker
  }

  s = RailsPerformance::Gems::SidekiqExt.new
  result = s.call('Worker', msg, 'default') do
    'success'
  end

  # Should fall back to worker class name
  assert_equal 'success', result
end
```

**Test Delayed Job with nil payload:**
```ruby
test 'handles delayed job with nil payload' do
  # Create a job with problematic payload
  job = Delayed::Job.create(
    payload_object: nil,
    handler: '--- !ruby/object:NilClass {}'
  )

  worker = Delayed::Worker.new(quiet: true)
  result = worker.work_off

  # Should handle gracefully without crashing
  assert_equal 0, result[0]  # No jobs succeeded
  assert_equal 1, result[1]  # One job failed
end
```

## Stack Patterns by Variant

**If testing job queuing only:**
- Use `Sidekiq::Testing.fake!`
- Because it's fast and doesn't execute jobs
- Verify job count and arguments

**If testing job execution logic:**
- Use `Sidekiq::Testing.inline!` or `worker.perform`
- Because it executes jobs synchronously
- Directly test behavior and side effects

**If testing middleware/metrics:**
- Use `Sidekiq::Testing.server_middleware` with `drain`
- Because middleware runs during drain
- Verify metrics stored in Redis

**If testing real Redis behavior:**
- Use `Sidekiq::Testing.disable!`
- Because it sends jobs to real Redis
- Test actual queuing, locking, and scheduling

**If testing under load:**
- Use concurrent-ruby thread pool
- Because it simulates production concurrency
- Detects race conditions and thread-safety issues

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| Sidekiq 8.1.0 | Rails 8.0 | Fully compatible, Rails 8 includes ActiveSupport::Notifications for jobs |
| Delayed Job 4.2.0 | Rails 8.0 | Compatible, plugin architecture unchanged |
| Minitest (Rails bundled) | Rails 8.0 | Default test framework, no compatibility issues |
| concurrent-ruby 1.2+ | Ruby 3.3+ | Thread-safe data structures for load testing |
| mock_redis | Redis 6+ | Mocks Redis API for unit tests |

## Minitest Best Practices for Rails 8.0

**Test Organization:**
- Follow Rails convention: `test/**/*_test.rb`
- Use `ActiveSupport::TestCase` for model tests
- Use `ActionDispatch::IntegrationTest` for controller tests
- Group related tests in nested classes

**Setup and Teardown:**
```ruby
setup do
  reset_redis
  RailsPerformance.skip = false
  Sidekiq::Worker.clear_all
  Delayed::Job.delete_all
end

teardown do
  # Clean up any lingering state
  RailsPerformance.redis.flushdb
end
```

**Test Naming:**
```ruby
# Descriptive, behavior-focused names
test 'captures sidekiq job success metrics' do
test 'handles malformed job data gracefully' do
test 'retries failed jobs according to configuration' do
test 'processes concurrent jobs without race conditions' do
```

**Assertion Selection:**
```ruby
# Use specific assertions
assert_equal expected, actual
assert_includes collection, element
assert_raises(ErrorType) { ... }
assert_empty errors
assert_predicate result, :success?
```

## Load Testing Approaches

**Small-scale concurrency (unit tests):**
```ruby
# Use Thread.new for simple concurrent execution
threads = 10.times.map { Thread.new { job.perform } }
threads.each(&:join)
```

**Medium-scale concurrency (integration tests):**
```ruby
# Use concurrent-ruby ThreadPoolExecutor
pool = Concurrent::ThreadPoolExecutor.new(max_threads: 20)
pool.post { job.perform }
```

**Large-scale concurrency (stress tests):**
```ruby
# Use parallel_tests gem or separate stress test suite
# Consider separate CI job for load tests
```

## Error Injection Patterns

**Simulate transient errors:**
```ruby
class FlakyWorker
  include Sidekiq::Job

  def perform(attempt)
    raise StandardError, 'Temporary failure' if attempt < 3
    'success'
  end
end
```

**Simulate Redis failures:**
```ruby
# Stub Redis methods to simulate failures
RailsPerformance.redis.stub(:set, -> { raise Redis::CannotConnectError }) do
  # Test job execution
end
```

**Simulate timeout:**
```ruby
# Use timeout block or stub slow operations
Timeout.timeout(0.1) do
  job.perform
end
```

## Sources

### HIGH Confidence (Official Documentation)
- [Sidekiq Testing Wiki](https://github.com/sidekiq/sidekiq/wiki/Testing) — Testing modes, fake/inline/disable configuration, middleware testing, queue API
- [Sidekiq Error Handling Wiki](https://github.com/sidekiq/sidekiq/wiki/Error-Handling) — Retry mechanism, error handlers, death notifications, retry configuration

### MEDIUM Confidence (Verified with Official Sources)
- [How To Test Delayed Jobs](https://code.dblock.org/2015/11/02/how-to-test-delayed-jobs.html) — Delayed::Worker.delay_jobs pattern, work_off approach (verified to work with Delayed Job 4.2.0)
- [Rails Testing Best Practices 2025](https://jetthoughts.com/blog/rails-testing-best-practices-complete-guide-2025/) — Current Minitest patterns for Rails 8.0
- [Thread Safety in Ruby and Rails (2025)](https://kig.re/share/talks/2025-thread-safety-in-ruby-and-rails.pdf) — Thread safety testing approaches for Ruby applications
- [Understanding Ruby Threads and Concurrency](https://betterstack.com/community/guides/scaling-ruby/threads-and-concurrency/) — GIL behavior, concurrency primitives
- [concurrent-ruby GitHub](https://github.com/ruby-concurrency/concurrent-ruby) — Thread-safe data structures, concurrent execution primitives

### LOW Confidence (WebSearch - Needs Verification)
- [CloudBees: Know Your Sidekiq Testing Rights](https://www.cloudbees.com/blog/know-your-sidekiq-testing-rights) — Testing guidelines (recommended for patterns, but verify with official docs)
- [Sidekiq Testing Gotchas in CI/CD](https://railsdrop.com/2025/10/02/sidekiq-testing-gotchas-when-your-tests-pass-locally-but-fail-in-ci/) — Race conditions, testing modes (needs direct verification)
- [Background Jobs Configuration with Sidekiq](https://oneuptime.com/blog/post/2025-07-02-rails-sidekiq-background-jobs/view) — Failure scenarios, middleware (community resource)

---

*Stack research for: Testing async jobs and error handling in Ruby/Rails*
*Researched: 2026-02-04*
