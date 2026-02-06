# Requirements: Rails Performance Concerns Fix

**Defined:** 2026-02-04
**Core Value:** The performance monitoring gem must be reliable, secure, and efficient in production environments without introducing overhead or data loss.

## v1 Requirements

### Redis & Performance

- [x] **REDI-01**: Replace Redis KEYS command with SCAN for non-blocking key iteration
- [x] **REDI-02**: Add configurable SCAN COUNT values for performance tuning
- [ ] **REDI-03**: Cache time calculations in base_report to avoid repeated computation

### Thread Safety

- [ ] **THREAD-01**: Migrate Thread.current to ActiveSupport::CurrentAttributes for automatic cleanup
- [ ] **THREAD-02**: Add development-mode validation to catch thread leaks
- [ ] **THREAD-03**: Add thread safety tests with concurrent-ruby for load scenarios

### Security

- [ ] **SEC-01**: Remove hardcoded default HTTP basic auth credentials
- [ ] **SEC-02**: Add production validation that raises error if credentials not explicitly set
- [ ] **SEC-03**: Add validation to disable debug mode in production environments
- [ ] **SEC-04**: Add configuration validation on application boot

### Tech Debt

- [ ] **DEBT-01**: Fix variable naming typo `skipable_rake_tasks` → `skippable_rake_tasks`
- [ ] **DEBT-02**: Fix variable assignment bug `@@recent_requests_limit` → `@@slow_requests_limit`
- [ ] **DEBT-03**: Add configurable log levels to reduce verbose logging overhead

### Testing

- [ ] **TEST-01**: Add Sidekiq monitoring tests for concurrent execution under load
- [ ] **TEST-02**: Add DelayedJob monitoring tests for concurrent execution under load
- [ ] **TEST-03**: Add error handling tests for Redis failures
- [ ] **TEST-04**: Add error handling tests for malformed job data
- [ ] **TEST-05**: Add error handling tests for Sidekiq job retries and failures

### Middleware & Integration

- [ ] **MIDL-01**: Add explicit dependency checks for middleware stack order
- [ ] **MIDL-02**: Add integration tests for middleware with different Rails versions

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Features
- **FEAT-01**: Rate limiting for performance dashboard
- **FEAT-02**: Authentication flexibility beyond HTTP basic auth
- **FEAT-03**: Automatic data pruning policies for Redis memory management
- **FEAT-04**: Connection pooling or sharding for Redis scaling

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Breaking changes to key format | Backwards compatibility must be maintained |
| New external dependencies | Must use existing Ruby standard library or gems |
| Redis data migration | SCAN works with existing key patterns |
| Rails version support changes | Must maintain compatibility with Rails 5.2+ |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| REDI-01 | Phase 1 | Complete |
| REDI-02 | Phase 1 | Complete |
| REDI-03 | Phase 5 | Pending |
| THREAD-01 | Phase 2 | Pending |
| THREAD-02 | Phase 2 | Pending |
| THREAD-03 | Phase 6 | Pending |
| SEC-01 | Phase 3 | Pending |
| SEC-02 | Phase 3 | Pending |
| SEC-03 | Phase 3 | Pending |
| SEC-04 | Phase 3 | Pending |
| DEBT-01 | Phase 4 | Pending |
| DEBT-02 | Phase 4 | Pending |
| DEBT-03 | Phase 5 | Pending |
| TEST-01 | Phase 6 | Pending |
| TEST-02 | Phase 6 | Pending |
| TEST-03 | Phase 6 | Pending |
| TEST-04 | Phase 6 | Pending |
| TEST-05 | Phase 6 | Pending |
| MIDL-01 | Phase 7 | Pending |
| MIDL-02 | Phase 7 | Pending |

**Coverage:**
- v1 requirements: 20 total
- Mapped to phases: 20
- Unmapped: 0

---
*Requirements defined: 2026-02-04*
*Last updated: 2026-02-05 after roadmap creation*
