# Codebase Concerns

**Analysis Date:** 2026-02-04

## Tech Debt

**Variable naming inconsistency:**
- Issue: Typo in variable name `skipable_rake_tasks` should be `skippable_rake_tasks`
- Files: `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance.rb`, `/Users/itisbryan/Desktop/personal/active_metrics/lib/generators/rails_performance/install/templates/initializer.rb`
- Impact: Inconsistent naming convention across the codebase
- Fix approach: Rename to `skippable_rake_tasks` for consistency

**Variable assignment bug:**
- Issue: Line 76 in `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance.rb` assigns `@@recent_requests_limit` to `slow_requests_limit`
- Files: `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance.rb`
- Impact: `slow_requests_limit` configuration option doesn't work as expected
- Fix approach: Change `@@recent_requests_limit = 500` to `@@slow_requests_limit = 500`

**Debug logging in production:**
- Issue: Debug logging can be left enabled in production
- Files: `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance/utils.rb`, `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance.rb`
- Impact: Performance overhead and potential information leakage
- Fix approach: Add validation in setup to ensure debug is false in production

## Known Bugs

**TODO comments in production code:**
- Issue: Multiple TODO comments in production code indicate incomplete features
- Files: `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance/instrument/metrics_collector.rb`, `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance/utils.rb`, `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance/reports/base_report.rb`, `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance/extensions/trace.rb`, `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance/gems/grape_ext.rb`
- Symptoms: Code that may not be fully implemented
- Trigger: When using the incomplete features
- Workaround: Avoid features marked with TODO comments

## Security Considerations

**Hardcoded credentials:**
- Risk: Default authentication credentials are hardcoded
- Files: `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance.rb`
- Current mitigation: Documentation warns about changing defaults
- Recommendations: Force users to set credentials or generate random defaults

**Redis KEYS command usage:**
- Risk: KEYS command blocks Redis server in production environments
- Files: `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance/utils.rb`
- Current mitigation: Only used in debug mode (when enabled)
- Recommendations: Replace with SCAN command or use specific key patterns

**Thread safety concerns:**
- Risk: Global state management with Thread.current may cause issues in concurrent scenarios
- Files: `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance/thread/current_request.rb`
- Current mitigation: Uses Thread isolation
- Recommendations: Add validation to ensure cleanup is called properly

## Performance Bottlenecks

**Redis KEYS command:**
- Problem: Uses blocking KEYS command for data retrieval
- Files: `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance/utils.rb`
- Cause: KEYS scans entire Redis keyspace
- Improvement path: Use SCAN command or maintain key patterns

**Inefficient time calculations:**
- Problem: Repeated time calculations without caching
- Files: `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance/reports/base_report.rb`
- Cause: Calling `kind_of_now` multiple times without caching
- Improvement path: Cache time calculations where possible

**Excessive logging:**
- Problem: Verbose logging in debug mode
- Files: `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance/utils.rb`
- Cause: Every Redis operation is logged
- Improvement path: Add configurable log levels

## Fragile Areas

**CurrentRequest cleanup:**
- Files: `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance/thread/current_request.rb`, `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance/instrument/metrics_collector.rb`
- Why fragile: Relies on proper cleanup in multiple async scenarios
- Safe modification: Add validation methods to check state
- Test coverage: Limited testing of cleanup scenarios

**Middleware integration:**
- Files: `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance/rails/middleware.rb`
- Why fragile: Depends on Rails middleware stack order
- Safe modification: Add explicit dependency checks
- Test coverage: Integration tests with different Rails versions

## Scaling Limits

**Redis memory usage:**
- Current capacity: Limited by Redis instance
- Limit: No automatic data pruning beyond duration
- Scaling path: Add automatic data aging policies

**Single-threaded Redis queries:**
- Current capacity: Limited by Redis single-threaded nature
- Limit: Concurrent requests queue up
- Scaling path: Add connection pooling or sharding

## Dependencies at Risk

**Browser gem:**
- Risk: `browser` gem may not be maintained
- Impact: Browser detection functionality breaks
- Migration plan: Replace with user agent string parsing or alternative library

**Isolate assets dependency:**
- Risk: `isolate_assets` gem is custom and unmaintained
- Impact: Asset isolation feature may break
- Migration plan: Implement custom asset isolation or remove if unused

## Missing Critical Features

**Rate limiting:**
- Problem: No built-in rate limiting for performance dashboard
- Blocks: Protection against DoS attacks
- Priority: High

**Authentication flexibility:**
- Problem: Only basic auth supported
- Blocks: Integration with existing auth systems
- Priority: Medium

## Test Coverage Gaps

**Async job monitoring:**
- What's not tested: Sidekiq and DelayedJob monitoring under load
- Files: `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance/gems/sidekiq_ext.rb`, `/Users/itisbryan/Desktop/personal/active_metrics/lib/rails_performance/gems/delayed_job_ext.rb`
- Risk: Data loss in high concurrency scenarios
- Priority: High

**Error handling:**
- What's not tested: Error cases and malformed data
- Files: Multiple gem extension files
- Risk: Silent failures in production
- Priority: Medium

---

*Concerns audit: 2026-02-04*