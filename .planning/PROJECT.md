# Rails Performance Concerns Fix

## What This Is

A comprehensive remediation project for the Rails Performance monitoring engine gem. This Rails mountable engine provides performance monitoring for web requests, background jobs (Sidekiq, Delayed Job), Grape APIs, and Rake tasks with a Redis-backed dashboard. The project will fix all identified code concerns including tech debt, security issues, performance bottlenecks, and fragile areas, while adding test coverage for async job monitoring and error handling.

## Core Value

The performance monitoring gem must be reliable, secure, and efficient in production environments without introducing overhead or data loss.

## Requirements

### Validated

- ✓ Request monitoring for Rails controllers — existing
- ✓ Background job monitoring (Sidekiq, Delayed Job) — existing
- ✓ API monitoring (Grape) — existing
- ✓ Rake task monitoring — existing
- ✓ Web dashboard with tables and charts — existing
- ✓ Redis-based time-series data storage — existing
- ✓ CSV export functionality — existing
- ✓ HTTP basic authentication — existing
- ✓ Custom access verification via proc — existing
- ✓ ActiveSupport::Notifications integration — existing
- ✓ Thread-safe request context tracking — existing
- ✓ Minitest test suite — existing

### Active

- [ ] Fix tech debt issues (variable naming typo, slow_requests_limit bug, debug logging validation)
- [ ] Fix hardcoded default credentials security issue
- [ ] Replace Redis KEYS command with SCAN
- [ ] Add thread safety validation for CurrentRequest cleanup
- [ ] Optimize time calculations in base_report
- [ ] Add configurable log levels
- [ ] Add middleware integration dependency checks
- [ ] Add tests for async job monitoring (Sidekiq, DelayedJob under load)
- [ ] Add tests for error handling and malformed data

### Out of Scope

- **Replacing browser gem** — External dependency, working as-is for now
- **Replacing isolate_assets gem** — External dependency, working as-is for now
- **Adding rate limiting** — New feature, deferred to future work
- **Authentication flexibility beyond basic auth** — New feature, deferred to future work
- **Redis memory optimization** — Scaling concern, not a bug
- **Connection pooling or sharding** — Scaling concern, not a bug
- **Automatic data pruning policies** — New feature, deferred

## Context

This is a Rails 8.0 engine gem that monitors application performance through ActiveSupport::Notifications. Data is stored in Redis with TTL-based expiration and displayed through a mounted dashboard. The codebase was recently audited revealing multiple concerns across tech debt, security, performance, and testing.

**Tech stack:** Ruby 3.3, Rails 8.0, Redis, Standard Ruby formatter, Minitest

**Key files:**
- `lib/rails_performance.rb` — Main module configuration
- `lib/rails_performance/models/` — Data record classes
- `lib/rails_performance/gems/` — Framework integrations
- `lib/rails_performance/thread/current_request.rb` — Thread-safe request context
- `lib/rails_performance/utils.rb` — Redis operations and utilities
- `lib/rails_performance/reports/base_report.rb` — Report aggregation

**Identified issues:**
- Variable naming typo: `skipable_rake_tasks` should be `skippable_rake_tasks`
- Bug: `@@recent_requests_limit` assigned instead of `@@slow_requests_limit`
- Security: Hardcoded default credentials for HTTP basic auth
- Performance: Blocking KEYS command in Redis operations
- Fragile: CurrentRequest cleanup may not be called properly in async scenarios
- Testing gaps: No tests for async jobs under load or error cases

## Constraints

- **Ruby version:** 3.3+ — Must maintain compatibility
- **Rails version:** 8.0+ — Must maintain compatibility
- **Redis:** Required for data storage — Changes must preserve existing data format
- **Backwards compatibility:** Existing users must not break — Configuration options must remain functional
- **Gem dependencies:** No new external dependencies — Use Ruby standard library or existing gems
- **Test framework:** Minitest — Must use existing test infrastructure
- **Code style:** Standard Ruby formatter — All code must pass standardrb

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Skip dependency replacement | browser and isolate_assets gems working as-is, replacement is high risk/low reward | — Pending |
| Skip new features | Focus on fixing existing issues first before adding capabilities | — Pending |
| Include test improvements | Async job and error handling tests are critical for reliability | — Pending |
| Replace KEYS with SCAN | KEYS blocks Redis in production, causing performance issues | — Pending |

---
*Last updated: 2026-02-04 after initialization*
