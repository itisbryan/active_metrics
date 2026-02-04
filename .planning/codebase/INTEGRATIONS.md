# External Integrations

**Analysis Date:** 2026-02-04

## APIs & External Services

**Background Job Queues:**
- Sidekiq - Monitoring for Sidekiq background jobs
  - SDK/Client: Sidekiq gem
  - Integration: `RailsPerformance::Gems::SidekiqExt`
- Delayed Job - Monitoring for Delayed::Record jobs
  - SDK/Client: delayed_job_active_record gem
  - Integration: `RailsPerformance::Gems::DelayedJobExt`

**API Monitoring:**
- Grape API - Monitoring for Grape API endpoints
  - SDK/Client: Grape gem
  - Integration: `RailsPerformance::Gems::GrapeExt`

## Data Storage

**Primary Storage:**
- Redis
  - Connection: `ENV['REDIS_URL']` (defaults to `redis://127.0.0.1:6379/0`)
  - Client: Redis gem
  - Used for: Performance metrics, request tracking, monitoring data

**Secondary Storage:**
- SQLite3 (for testing/demo app)
  - Connection: Rails database.yml
  - ORM: ActiveRecord

**File Storage:**
- Local filesystem only
- Asset storage: `app/assets/images/` for static images

**Caching:**
- Redis (via RailsPerformance.redis)
- No external caching service integration

## Authentication & Identity

**Auth Provider:**
- Optional HTTP Basic Authentication
  - Implementation: Configurable via `RailsPerformance.http_basic_authentication_enabled`
  - Credentials: `RailsPerformance.http_basic_authentication_user_name` and `RailsPerformance.http_basic_authentication_password`
- User authentication integration available via custom proc
  - Implementation: `RailsPerformance.verify_access_proc`
  - Example: Devise user checking for admin access

## Monitoring & Observability

**Error Tracking:**
- No external error tracking service integration
- Built-in crash monitoring in dashboard

**Performance Monitoring:**
- Custom performance tracking via ActiveSupport::Notifications
- No third-party APM services (goal is to be 3rd party dependency-free)

**Resource Monitoring:**
- Optional system resource monitoring
  - CPU monitoring via Sys::CPU gem
  - Memory monitoring via GetProcessMem gem
  - Disk monitoring via Sys::Filesystem gem

## CI/CD & Deployment

**Hosting:**
- Gem hosted on GitHub
- RubyGems.org for distribution

**CI Pipeline:**
- GitHub Actions (`.github/workflows/ruby.yml`)
- Multi-version testing with Appraisal
- Code quality checks with Standard.rb

## Environment Configuration

**Required env vars:**
- `REDIS_URL` - Redis connection URL (optional, defaults to localhost)
- `RAILS_PERFORMANCE_SERVER_CONTEXT` - Server context (optional, defaults to 'rails')
- `RAILS_PERFORMANCE_SERVER_ROLE` - Server role (optional, defaults to 'web')

**Secrets location:**
- Redis credentials via REDIS_URL
- HTTP basic auth credentials via gem configuration

## Webhooks & Callbacks

**Incoming:**
- None (monitoring dashboard, not webhook-based)

**Outgoing:**
- None (standalone monitoring solution, no external integrations)

## CSV Export

**Data Export:**
- Built-in CSV export functionality for:
  - Error reports
  - Request reports
  - Recent requests
  - Slow requests
- Implementation: `export_to_csv` method in controllers

---

*Integration audit: 2026-02-04*
```