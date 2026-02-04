# Technology Stack

**Analysis Date:** 2026-02-04

## Languages

**Primary:**
- Ruby 3.3 - Core language for the Rails Performance gem
- Ruby on Rails 8.0.0 - Web framework for the gem and test app

## Runtime

**Environment:**
- Ruby on Rails 8.0.0
- Ruby 3.3 (via Gemfile.lock)

**Package Manager:**
- Bundler (Gemfile/Gemfile.lock)
- Appraisal for multi-version testing

## Frameworks

**Core:**
- Rails Engine - Mountable engine for Rails applications
- Rails Performance - Performance monitoring and analytics gem

**Testing:**
- Minitest 5.x - Unit testing framework
- Simplecov - Test coverage reporting

**Build/Dev:**
- Standard.rb - Ruby code formatter
- Sprockets-rails - Asset pipeline (legacy support)
- Isolate Assets - Asset isolation for engine development

## Key Dependencies

**Critical:**
- Redis - Data storage for performance metrics
- Browser - User agent parsing for request tracking
- Active Support - Core Rails utilities and extensions

**Monitoring:**
- Delayed Job Active Record - Background job monitoring
- Sidekiq - Background job monitoring
- Grape - API monitoring support

**Infrastructure:**
- SQLite3 - Development/test database
- Puma - Web server
- Daemons - Process daemon management

## Configuration

**Environment:**
- Rails 8.0 environment configuration
- Multi-environment support (development, test, production)
- Environment-specific Redis configuration

**Build:**
- Rails engine isolation with isolate_assets
- Gemspec-defined dependencies
- Appraisal matrix for Rails version testing

## Platform Requirements

**Development:**
- Ruby 3.3
- Rails 8.0.0
- SQLite3
- Redis
- Bundler

**Production:**
- Ruby 3.3+ (compatible)
- Rails 8.0+ (compatible)
- Redis for data storage
- Web server (Puma recommended)

---

*Stack analysis: 2026-02-04*
```