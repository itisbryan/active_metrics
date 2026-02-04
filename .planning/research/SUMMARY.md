# Project Research Summary

**Project:** Rails Performance Gem - Performance & Reliability Improvements
**Domain:** Rails Performance Monitoring Gem
**Researched:** 2026-02-04
**Confidence:** HIGH

## Executive Summary

The Rails Performance gem requires critical fixes to address production blocking issues (Redis KEYS command), thread safety concerns (Thread.current data leakage), security vulnerabilities (default credentials), and testing gaps. This is a mature monitoring gem that tracks Rails request performance, Sidekiq jobs, and DelayedJob metrics, storing data in Redis with time-series key patterns.

The recommended approach prioritizes the Redis KEYS to SCAN migration as Phase 1, as KEYS blocks the entire Redis server during key iteration and can halt production environments. The migration is low-risk: SCAN uses the same glob-style patterns, requires no key format changes, and the existing redis-rb gem (5.4.1) fully supports `scan` and `scan_each` methods. Thread safety improvements using ActiveSupport::CurrentAttributes should follow, as they eliminate manual cleanup and provide automatic reset via Rails Executor callbacks. Security hardening (removing default credentials, adding production validation) and comprehensive testing for async job error handling complete the reliability improvements.

Key risks include potential breaking changes if the Redis SCAN migration changes behavior under concurrent load, thread safety issues that only appear under production concurrency, and the security risk of hardcoded default credentials. Mitigation strategies include using feature flags for the SCAN migration, adding thread safety tests with concurrent-ruby, and implementing fail-fast configuration validation that raises errors in production unless credentials are explicitly set.

## Key Findings

### Recommended Stack

**From REDIS.md and THREAD.md:**

**Core technologies:**
- **Redis SCAN** (Redis 2.8.0+): Non-blocking key iteration — Official replacement for KEYS command; incremental iteration prevents blocking production Redis servers
- **ActiveSupport::CurrentAttributes** (Rails 5.2+): Thread-safe per-request state — Automatic cleanup via Rails Executor, fiber-safe in Rails 8+, eliminates Thread.current leakage
- **redis-rb** (5.4.1+): Ruby Redis client — Gem's current dependency; provides `scan`, `scan_each` methods with proper SCAN support
- **Sidekiq::Testing** (8.1.0+): Sidekiq test harness — Official testing modes (fake, inline, disable) for comprehensive async job testing

**Version requirements:**
- Redis 2.8.0+ for SCAN support (already available)
- Rails 5.2+ for CurrentAttributes (gem supports older Rails, but can conditionally use CurrentAttributes when available)
- Ruby 3.3+ for full fiber safety with Rails 8.0+

### Expected Features

**From implied features and research:**

**Must have (table stakes):**
- Non-blocking Redis key iteration — Production safety requirement
- Thread-safe request context tracking — Prevents data leakage between requests/jobs
- Production-safe credential management — No hardcoded passwords
- Error handling for async jobs — Graceful degradation when Redis fails or jobs error

**Should have (competitive):**
- Comprehensive test coverage for thread safety — Concurrent load tests
- SCAN migration with feature flag — Gradual rollout capability
- Automatic cleanup validation — Development-mode assertions for thread leaks

**Defer (v2+):**
- Custom Redis scan optimization (COUNT tuning) — Can be added after migration works
- Performance metrics for SCAN iteration itself — Nice-to-have monitoring

### Architecture Approach

**From THREAD.md and current codebase:**

**Major components:**
1. **Redis Storage Layer** (lib/rails_performance/utils.rb) — Fetches performance data from Redis using KEYS (needs SCAN migration)
2. **Thread::CurrentRequest** (lib/rails_performance/thread/current_request.rb) — Per-request context tracking with manual cleanup (needs CurrentAttributes migration)
3. **Middleware & Extensions** (lib/rails_performance/rails/middleware.rb, lib/rails_performance/gems/sidekiq_ext.rb) — Integration points that call CurrentRequest.init/cleanup (need CurrentAttributes refactoring)
4. **Data Models** (lib/rails_performance/models/) — RequestRecord, TraceRecord, SidekiqRecord with time-series key patterns

**Key patterns:**
- Time-series key pattern: `performance|controller|HomeController|action|index|...|datetime|20260204T0523|...|END|1.0.0`
- SCAN patterns match same glob-style patterns as KEYS, enabling transparent migration
- CurrentAttributes integrates with Rails Executor's `to_complete` callback for automatic cleanup

### Critical Pitfalls

**From all research files:**

1. **KEYS command blocks Redis** — Migrate to SCAN immediately; KEYS halts entire Redis server during iteration, causing production outages
2. **Thread.current data leakage** — Manual cleanup is unreliable; migrate to CurrentAttributes for automatic reset via Rails Executor
3. **Hardcoded default credentials** — Security vulnerability; require explicit configuration via ENV or Rails Credentials, raise error if missing in production
4. **Missing thread safety tests** — Issues only appear under concurrent load; add tests with concurrent-ruby to detect race conditions
5. **Insufficient error handling** — Redis failures and job errors can crash the middleware; wrap Redis operations and add graceful degradation

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Redis SCAN Migration
**Rationale:** KEYS command is a production blocking issue that can halt Redis servers; highest priority due to operational risk
**Delivers:** Non-blocking key iteration using SCAN command
**Addresses:** Redis blocking (REDIS.md), Production safety
**Avoids:** KEYS command blocking Redis server

**Implementation approach:**
- Replace `redis.keys(query)` with `redis.scan_each(match: query).to_a` in lib/rails_performance/utils.rb:30-41
- Add feature flag for gradual rollout
- No key format changes required; patterns remain compatible
- Uses existing redis-rb gem (5.4.1)

### Phase 2: Thread Safety with CurrentAttributes
**Rationale:** Thread.current leakage causes data corruption between requests; CurrentAttributes provides automatic cleanup and fiber safety
**Delivers:** Thread-safe and fiber-safe request context tracking
**Uses:** ActiveSupport::CurrentAttributes, Rails Executor integration
**Implements:** New RailsPerformance::Current class, refactored middleware/extensions

**Implementation approach:**
- Create lib/rails_performance/current.rb extending ActiveSupport::CurrentAttributes
- Migrate attributes: request_id, tracings, ignore, data, record
- Remove manual CurrentRequest.cleanup calls from middleware and job extensions
- Add development-mode validation to catch any remaining Thread.current usage

### Phase 3: Security Hardening
**Rationale:** Default credentials create security vulnerabilities; production must enforce explicit configuration
**Delivers:** Secure-by-default configuration with fail-fast validation
**Uses:** Rails Credentials, Rails.env.production? checks, config.filter_parameters
**Implements:** Configuration validation on boot, removal of hardcoded defaults

**Implementation approach:**
- Remove any hardcoded default passwords
- Add `config.verify_access_proc` that raises error in production unless explicitly set
- Validate all required secrets on application boot
- Use config.require_master_key = true for production

### Phase 4: Comprehensive Testing for Async Jobs
**Rationale:** Current test coverage for Sidekiq/DelayedJob error handling is insufficient; reliability requires testing failure scenarios
**Delivers:** Robust test suite for async job instrumentation
**Uses:** Sidekiq::Testing, Delayed::Worker.work_off, concurrent-ruby, mock_redis
**Implements:** Tests for concurrent execution, Redis failures, malformed data, retries

**Implementation approach:**
- Use Sidekiq::Testing.fake! for queuing tests
- Use Sidekiq::Testing.inline! with server_middleware for execution tests
- Add load tests with concurrent-ruby ThreadPoolExecutor
- Test Redis failure scenarios (connection failure, timeout, flush during execution)
- Test malformed job data handling

### Phase Ordering Rationale

- **Phase 1 first**: Redis KEYS is a production blocking issue; causes immediate operational problems
- **Phase 2 second**: Thread safety affects data integrity but may not cause immediate failures; builds on Rails 5.2+ infrastructure
- **Phase 3 third**: Security hardening is important but less urgent than blocking/leakage issues; independent of other phases
- **Phase 4 last**: Testing validates the fixes from Phases 1-3; comprehensive tests require stable implementation

**Dependency considerations:**
- Phase 2 (CurrentAttributes) can proceed in parallel with Phase 1, as they address different subsystems
- Phase 4 (Testing) depends on completion of Phases 1-3 to have stable code to test
- Phase 3 (Security) is independent and can be done anytime

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1**: SCAN migration needs investigation into optimal COUNT values for time-series key patterns; may need performance testing with production-like datasets
- **Phase 2**: CurrentAttributes migration needs verification of Rails Executor integration points in all supported Rails versions (5.2 through 8.0)

Phases with standard patterns (skip research-phase):
- **Phase 3**: Security patterns are well-documented in Rails Security Guide; straightforward implementation
- **Phase 4**: Testing patterns are well-established; Sidekiq::Testing and Delayed::Worker have official documentation

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack (Redis SCAN) | HIGH | Verified with Redis official docs (8.4), redis-rb source code confirms scan_each support |
| Stack (CurrentAttributes) | HIGH | Verified with Rails official API docs, Rails Guides, GitHub source code |
| Features (implied) | MEDIUM | Inferred from gem purpose and current implementation; not explicitly researched |
| Architecture | HIGH | Analyzed current codebase structure; CurrentAttributes integration well-documented |
| Pitfalls | HIGH | All pitfalls verified with official sources and recent expert articles (2025) |
| Security | MEDIUM | Security best practices verified with Rails Security Guide; gem-specific analysis needed |
| Testing | MEDIUM | Sidekiq::Testing patterns verified with official wiki; Delayed Job patterns from community guides |

**Overall confidence:** HIGH

**Reasoning:** Core technical recommendations (SCAN, CurrentAttributes) are verified with official documentation and source code. Research sources include Redis 8.4 docs (verified 2026-01-30), Rails official API and Guides, redis-rb source code, and recent expert articles from 2025. Only security and testing areas are MEDIUM confidence because they require gem-specific implementation details not covered in general guides.

### Gaps to Address

- **SCAN performance tuning**: Optimal COUNT values for time-series key patterns need load testing with production-like datasets; handle during Phase 1 implementation by testing with realistic data volumes
- **Rails version compatibility**: CurrentAttributes available in Rails 5.2+ but gem may support older Rails versions; handle by conditionally using CurrentAttributes when available, falling back to Thread.current with ensure blocks for older Rails
- **Backwards compatibility**: Ensure SCAN migration doesn't break existing user deployments; handle via feature flag and gradual rollout with monitoring

## Sources

### Primary (HIGH confidence)
- **Redis Official SCAN Documentation** (https://redis.io/docs/latest/commands/scan/) — SCAN guarantees, MATCH/COUNT options, complexity analysis
- **Ruby on Rails Threading and Code Execution Guide** (https://guides.rubyonrails.org/threading_and_code_execution.html) — CurrentAttributes, Rails Executor, thread safety patterns
- **ActiveSupport::CurrentAttributes API** (https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html) — Official API documentation
- **redis-rb source code** (https://github.com/redis/redis-rb/blob/master/lib/redis/commands/keys.rb) — Actual Ruby gem implementation
- **Rails Security Guide** (https://guides.rubyonrails.org/security.html) — Credential management, parameter filtering, production security
- **Sidekiq Testing Wiki** (https://github.com/sidekiq/sidekiq/wiki/Testing) — Official testing patterns

### Secondary (MEDIUM confidence)
- **thoughtbot: Thread Safety with CurrentAttributes** (July 15, 2025) — Anti-patterns and best practices
- **Better Stack: Understanding Ruby Threads and Concurrency** (Sept 2025) — Thread safety testing approaches
- **Thread Safety in Ruby and Rails** (Feb 2025 presentation by kig.re) — Expert presentation on concurrency
- **Rails GitHub Issues #43773, #48279, #49227** — Official discussions on IsolatedExecutionState and fiber safety
- **How To Test Delayed Jobs** (2015, verified with Delayed Job 4.2.0) — work_off pattern for testing

### Tertiary (LOW confidence)
- **Medium articles on Redis KEYS vs SCAN** — Verified against official docs; used for examples only
- **Reddit community discussions** — Used for community patterns only; not relied upon for technical claims
- **WebSearch results on testing patterns** — Cross-referenced with official documentation

---
*Research completed: 2026-02-04*
*Ready for roadmap: yes*
