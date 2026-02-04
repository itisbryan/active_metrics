# Architecture

**Analysis Date:** 2026-02-04

## Pattern Overview

**Overall:** Rails Engine with MVC pattern + Data collection pipeline

**Key Characteristics:**
- Engine-based architecture isolates RailsPerformance namespace
- Event-driven data collection via ActiveSupport::Notifications
- Redis-backed time-series data storage
- Widget-based UI composition
- Multi-framework support (Rails, Sidekiq, Grape, Delayed Job, Rake)

## Layers

**Controller Layer:**
- Purpose: Handles HTTP requests, data preparation, and response rendering
- Location: `app/controllers/rails_performance/`
- Contains: Controllers for different data types (requests, sidekiq, etc.)
- Depends on: Models, DataSource, Widgets
- Used by: HTTP clients via mounted engine

**Model Layer:**
- Purpose: Data persistence and business logic for tracked events
- Location: `lib/rails_performance/models/`
- Contains: Record classes for different frameworks
- Depends on: Redis, Utils
- Used by: DataSource, Controllers

**DataSource Layer:**
- Purpose: Query interface for retrieving performance data
- Location: `lib/rails_performance/data_source.rb`
- Contains: Query builders for different data types
- Depends on: Models, Utils, Redis
- Used by: Controllers, Reports, Widgets

**Widget Layer:**
- Purpose: UI components for data visualization
- Location: `lib/rails_performance/widgets/`
- Contains: Chart and Table widgets
- Depends on: DataSource, Views
- Used by: Controllers for UI rendering

**Report Layer:**
- Purpose: Data aggregation and analysis
- Location: `lib/rails_performance/reports/`
- Contains: Report classes for different metrics
- Depends on: DataSource, Models
- Used by: Controllers for data summarization

**Instrumentation Layer:**
- Purpose: Event collection and middleware
- Location: `lib/rails_performance/instrument/`, `lib/rails_performance/rails/middleware.rb`
- Contains: Metrics collector and middleware
- Depends on: ActiveSupport::Notifications, Rails
- Used by: Rails application for data collection

## Data Flow

**Data Collection Flow:**

1. **Request/Event Trigger** - Rails action, Sidekiq job, or other tracked event
2. **Middleware Interception** - `RailsPerformance::Rails::Middleware` captures metrics
3. **Event Publishing** - `ActiveSupport::Notifications` published to `MetricsCollector`
4. **Record Creation** - `RailsPerformance::Models::RequestRecord` or similar saves to Redis
5. **Query Processing** - `DataSource` builds queries and retrieves records
6. **Widget Rendering** - Widgets process data for UI display
7. **Response Generation** - Controllers render views with widget data

**State Management:**
- Redis stores time-series data with TTL
- In-memory collection aggregation for time periods
- Widget state managed through DataSource queries

## Key Abstractions

**Record Base:**
- Purpose: Common interface for all performance records
- Examples: `[lib/rails_performance/models/base_record.rb]`
- Pattern: Template method with JSON-based data storage

**Widget Base:**
- Purpose: Common interface for UI components
- Examples: `[lib/rails_performance/widgets/base.rb]`
- Pattern: Template method with partial path resolution

**DataSource:**
- Purpose: Query abstraction for different data types
- Examples: `[lib/rails_performance/data_source.rb]`
- Pattern: Factory pattern with query builders

**Report Base:**
- Purpose: Common interface for data aggregation
- Examples: `[lib/rails_performance/reports/base_report.rb]`
- Pattern: Template method with data extraction

## Entry Points

**Engine Mount:**
- Location: `[lib/rails_performance/engine.rb]`
- Triggers: Rails app initialization
- Responsibilities: Load middleware, initialize monitoring, configure extensions

**Base Controller:**
- Location: `[app/controllers/rails_performance/base_controller.rb]`
- Triggers: HTTP requests to mounted engine
- Responsibilities: Authentication, layout, CSP headers

**Main Controller:**
- Location: `[app/controllers/rails_performance/rails_performance_controller.rb]`
- Triggers: Specific endpoint requests
- Responsibilities: Data preparation, widget instantiation, response rendering

**Middleware:**
- Location: `[lib/rails_performance/rails/middleware.rb]`
- Triggers: Every Rails request
- Responsibilities: Metrics collection, trace storage

## Error Handling

**Strategy:** Graceful degradation with configurable features

**Patterns:**
- Feature flags enable/disable monitoring
- Redis connection failures silently ignored
- Missing data handled with empty states
- CSV export failures return plain text errors

## Cross-Cutting Concerns

**Authentication:**
- HTTP basic auth support
- Custom access verification proc
- Role-based access control via middleware

**Data Storage:**
- Redis with TTL-based expiration
- Time-based partitioning in keys
- JSON serialization for complex data

**UI Security:**
- CSP headers for embedded content
- Asset isolation via engine_assets
- XSS prevention in data rendering

---

*Architecture analysis: 2026-02-04*