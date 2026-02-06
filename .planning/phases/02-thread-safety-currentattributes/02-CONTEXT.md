# Phase 2: Thread Safety with CurrentAttributes - Context

**Gathered:** 2026-02-06
**Status:** Ready for planning

## Phase Boundary

Migrate from Thread.current-based request tracking (CurrentRequest) to Rails CurrentAttributes for automatic cleanup via Rails Executor. Replace manual cleanup calls with automatic reset mechanism across Rails middleware, background job integrations (Sidekiq, DelayedJob), and Rake tasks. Add development-mode validation to detect Thread.current usage.

## Implementation Decisions

### Migration approach
- Big bang migration: Create Current, migrate everything, then remove CurrentRequest. Single deployment, brief cutover.
- CurrentRequest class: Deprecate first (keep as deprecated alias for one version), then remove in follow-up
- Manual cleanup calls: Remove only after Current is verified working — safety net retained during transition
- User upgrade process: Multiple steps (Add Current → Migrate consumers → Remove cleanup)

### Current attributes design
- Keep all existing CurrentRequest attributes: request_id, tracings, ignore (read-only); data, record (read-write)
- Add new attributes: Deferred to planning — specifics to be determined
- Preserve camelCase naming: Current.request_id (not current.request_id) — maintains compatibility
- RailsPerformance::Current extends ActiveSupport::CurrentAttributes

### Validation strategy
- Development-mode validation: Warnings only (non-disruptive feedback)
- Environment scope: Development + test environments (not production)
- Detection method: Pattern matching for Thread.current[:rp_current_request] — targeted, fewer false positives

### Rails version support
- Unified approach: Single CurrentAttributes implementation across all Rails versions (5.2 through 8.0)
- CI testing: Test representative versions (5.2, 6.1, 7.2, 8.0) rather than all versions
- Minimum Rails: Require Rails 5.2+ (CurrentAttributes availability), no shims for older versions

### Claude's Discretion
- Exact deprecation message wording for CurrentRequest
- Whether to add configurable flag to enable/disable validation warnings
- Specific new attributes to add to Current (deferred to planning)
- Test matrix details for representative Rails versions

## Specific Ideas

CurrentRequest attributes (from lib/rails_performance/thread/current_request.rb):
- `request_id` — SecureRandom.hex(16) unique identifier
- `tracings` — Trace collection
- `ignore` — Ignore flag (Set/Symbol)
- `data` — Generic data storage
- `record` — Event record storage

## Deferred Ideas

None — discussion stayed within phase scope.

---

*Phase: 02-thread-safety-currentattributes*
*Context gathered: 2026-02-06*
