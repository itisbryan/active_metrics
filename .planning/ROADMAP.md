# Roadmap: Rails Performance Concerns Fix

## Overview

This roadmap addresses critical production-blocking issues and technical debt in the Rails Performance monitoring engine gem. The journey begins with the highest-priority Redis SCAN migration to eliminate production-blocking KEYS commands, followed by thread safety improvements using CurrentAttributes to prevent data leakage, security hardening to remove hardcoded credentials, tech debt cleanup for naming and assignment bugs, performance optimizations for time calculations and logging, and comprehensive testing for async jobs and error handling. The project concludes with middleware integration validation to ensure proper ordering across Rails versions.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Redis SCAN Migration** - Replace blocking KEYS command with non-blocking SCAN for production safety
- [ ] **Phase 2: Thread Safety with CurrentAttributes** - Migrate Thread.current to automatic cleanup via Rails Executor
- [ ] **Phase 3: Security Hardening** - Remove hardcoded credentials and enforce production-safe configuration
- [ ] **Phase 4: Tech Debt Fixes** - Fix variable naming typo, assignment bug, and logging validation
- [ ] **Phase 5: Performance Optimizations** - Cache time calculations and add configurable log levels
- [ ] **Phase 6: Comprehensive Testing** - Add async job tests, thread safety tests, and error handling tests
- [ ] **Phase 7: Middleware & Integration Validation** - Add dependency checks and cross-version integration tests

## Phase Details

### Phase 1: Redis SCAN Migration

**Goal**: Eliminate production-blocking Redis KEYS command by migrating to non-blocking SCAN iteration

**Depends on**: Nothing (first phase)

**Requirements**: REDI-01, REDI-02

**Success Criteria** (what must be TRUE):
1. Dashboard loads performance data without blocking Redis server during key iteration
2. Large Redis key sets (10,000+ keys) iterate incrementally without timeout
3. SCAN COUNT values are configurable for performance tuning
4. Existing time-series key patterns work without modification (no breaking changes)
5. Feature flag allows gradual rollout in production environments

**Plans**: 7 plans

**Completed:** 2026-02-06

Plans:
- [x] 01-01-PLAN.md — Add feature flag configuration and SCAN implementation in utils.rb
- [x] 01-02-PLAN.md — Add error handling and COUNT validation for SCAN
- [x] 01-03-PLAN.md — Create integration tests for SCAN vs KEYS compatibility
- [x] 01-04-PLAN.md — Create performance benchmark script for SCAN validation
- [x] 01-05-PLAN.md — Verify Grape API integration SCAN compatibility
- [x] 01-06-PLAN.md — Create SCAN migration documentation and rollout guide
- [x] 01-07-PLAN.md — Update README and CHANGELOG with SCAN feature

### Phase 2: Thread Safety with CurrentAttributes

**Goal**: Eliminate Thread.current data leakage through Rails Executor automatic cleanup

**Depends on**: Phase 1

**Requirements**: THREAD-01, THREAD-02

**Success Criteria** (what must be TRUE):
1. Request context (request_id, tracings, data) automatically resets after each request completes
2. Background job context automatically resets after each job completes
3. Development mode raises errors if Thread.current used for request tracking
4. CurrentAttributes works correctly with Rails 5.2 through 8.0
5. Manual CurrentRequest.cleanup calls removed from all middleware and extensions

**Plans**: 7-9 plans

Plans:
- [ ] 02-01: Create RailsPerformance::Current extending ActiveSupport::CurrentAttributes
- [ ] 02-02: Migrate request_id, tracings, ignore, data, record attributes to Current
- [ ] 02-03: Refactor Rails middleware to use Current instead of CurrentRequest
- [ ] 02-04: Refactor Sidekiq extension to use Current instead of CurrentRequest
- [ ] 02-05: Refactor DelayedJob extension to use Current instead of CurrentRequest
- [ ] 02-06: Refactor Rake task integration to use Current instead of CurrentRequest
- [ ] 02-07: Add development-mode validation for Thread.current usage
- [ ] 02-08: Remove CurrentRequest class and all cleanup calls
- [ ] 02-09: Add Rails version compatibility tests for CurrentAttributes

### Phase 3: Security Hardening

**Goal**: Remove hardcoded credentials and enforce production-safe configuration

**Depends on**: Phase 2

**Requirements**: SEC-01, SEC-02, SEC-03, SEC-04

**Success Criteria** (what must be TRUE):
1. No hardcoded default credentials exist in any configuration file
2. Production environment raises error at boot if HTTP auth credentials not explicitly set
3. Production environment raises error at boot if debug mode enabled
4. Configuration validation runs on application boot with clear error messages
5. ENV variables and Rails Credentials properly supported for auth configuration

**Plans**: 8-10 plans

Plans:
- [ ] 03-01: Audit all configuration files for hardcoded credentials
- [ ] 03-02: Remove default credentials from configuration
- [ ] 03-03: Add production validation for HTTP auth credentials
- [ ] 03-04: Add production validation for debug mode
- [ ] 03-05: Implement configuration validation on application boot
- [ ] 03-06: Add ENV variable support for auth configuration
- [ ] 03-07: Add Rails Credentials integration for auth configuration
- [ ] 03-08: Update configuration documentation with security requirements
- [ ] 03-09: Add security tests for configuration validation
- [ ] 03-10: Add upgrade guide for existing deployments

### Phase 4: Tech Debt Fixes

**Goal**: Fix variable naming typo, assignment bug, and logging validation issues

**Depends on**: Phase 3

**Requirements**: DEBT-01, DEBT-02, DEBT-03

**Success Criteria** (what must be TRUE):
1. Configuration uses correct spelling `skippable_rake_tasks` throughout codebase
2. Slow requests limit properly assigned to `@@slow_requests_limit` variable
3. Debug logging only occurs when explicitly enabled via configuration
4. All deprecated variable names raise deprecation warnings or removed
5. Code passes Standard Ruby formatter checks

**Plans**: 6-8 plans

Plans:
- [ ] 04-01: Rename `skipable_rake_tasks` to `skippable_rake_tasks` in configuration
- [ ] 04-02: Add alias for backwards compatibility with deprecation warning
- [ ] 04-03: Fix `@@slow_requests_limit` assignment bug in configuration
- [ ] 04-04: Add validation for debug mode configuration
- [ ] 04-05: Update all references to use correct variable names
- [ ] 04-06: Add tests for configuration variable assignments
- [ ] 04-07: Run Standard Ruby formatter and fix any issues
- [ ] 04-08: Update upgrade documentation for variable name changes

### Phase 5: Performance Optimizations

**Goal**: Reduce computation overhead through time calculation caching and configurable logging

**Depends on**: Phase 4

**Requirements**: REDI-03, DEBT-03

**Success Criteria** (what must be TRUE):
1. Base report time calculations cached within request cycle
2. Repeated time zone conversions eliminated in report generation
3. Log level configuration reduces verbose logging overhead in production
4. Dashboard load time improves measurably with optimizations
5. Log level can be configured via ENV variable or configuration file

**Plans**: 6-8 plans

Plans:
- [ ] 05-01: Profile base_report time calculation performance
- [ ] 05-02: Implement time calculation caching in base_report
- [ ] 05-03: Add request lifecycle hooks for cache invalidation
- [ ] 05-04: Implement configurable log levels (debug, info, warn, error)
- [ ] 05-05: Add ENV variable support for log level configuration
- [ ] 05-06: Add performance benchmarks for optimization validation
- [ ] 05-07: Update logging documentation with performance considerations
- [ ] 05-08: Add tests for time calculation cache lifecycle

### Phase 6: Comprehensive Testing

**Goal**: Add robust test coverage for async jobs, thread safety, and error handling

**Depends on**: Phase 5

**Requirements**: THREAD-03, TEST-01, TEST-02, TEST-03, TEST-04, TEST-05

**Success Criteria** (what must be TRUE):
1. Sidekiq monitoring tests pass with 100+ concurrent jobs
2. DelayedJob monitoring tests pass with 100+ concurrent jobs
3. Redis connection failures handled gracefully without crashes
4. Malformed job data handled with proper error logging
5. Sidekiq job retries and failures properly tracked and reported
6. Thread safety tests detect race conditions under concurrent load
7. Test suite achieves >90% code coverage for modified files

**Plans**: 10-12 plans

Plans:
- [ ] 06-01: Add concurrent-ruby gem dependency for thread safety tests
- [ ] 06-02: Create Sidekiq concurrent execution tests (100+ jobs)
- [ ] 06-03: Create DelayedJob concurrent execution tests (100+ jobs)
- [ ] 06-04: Add Redis connection failure tests for utils.rb
- [ ] 06-05: Add Redis timeout tests for dashboard operations
- [ ] 06-06: Add malformed job data tests for Sidekiq
- [ ] 06-07: Add malformed job data tests for DelayedJob
- [ ] 06-08: Add Sidekiq retry and failure tracking tests
- [ ] 06-09: Add thread safety tests with concurrent-ruby
- [ ] 06-10: Add thread leak detection tests
- [ ] 06-11: Measure and document test coverage improvements
- [ ] 06-12: Add CI configuration for comprehensive test suite

### Phase 7: Middleware & Integration Validation

**Goal**: Add middleware dependency checks and cross-version integration tests

**Depends on**: Phase 6

**Requirements**: MIDL-01, MIDL-02

**Success Criteria** (what must be TRUE):
1. Middleware order validation runs on application boot
2. Integration tests pass for Rails 5.2, 6.0, 6.1, 7.0, 7.1, 7.2, and 8.0
3. Missing middleware dependencies detected with clear error messages
4. Grape API integration tests pass across supported Grape versions
5. Rake task integration tests pass with concurrent task execution
6. Upgrade guide documents middleware ordering requirements

**Plans**: 7-9 plans

Plans:
- [ ] 07-01: Audit middleware stack order requirements
- [ ] 07-02: Implement middleware dependency validation on boot
- [ ] 07-03: Add Rails 5.2 integration tests
- [ ] 07-04: Add Rails 6.x integration tests
- [ ] 07-05: Add Rails 7.x integration tests
- [ ] 07-06: Add Rails 8.0 integration tests
- [ ] 07-07: Add Grape API integration tests
- [ ] 07-08: Add Rake task concurrent execution tests
- [ ] 07-09: Update middleware documentation with ordering requirements

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Redis SCAN Migration | 7/7 | Complete | 2026-02-06 |
| 2. Thread Safety | 0/9 | Not started | - |
| 3. Security Hardening | 0/10 | Not started | - |
| 4. Tech Debt Fixes | 0/8 | Not started | - |
| 5. Performance Optimizations | 0/8 | Not started | - |
| 6. Comprehensive Testing | 0/12 | Not started | - |
| 7. Middleware & Integration | 0/9 | Not started | - |
