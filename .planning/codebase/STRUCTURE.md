# Codebase Structure

**Analysis Date:** 2026-02-04

## Directory Layout

```
active_metrics/
├── app/                        # Engine controllers and views
│   ├── controllers/rails_performance/    # Main controllers
│   │   ├── base_controller.rb           # Base with auth and CSP
│   │   └── rails_performance_controller.rb # Main dashboard controller
│   │   └── concerns/csv_exportable.rb    # Export functionality
│   ├── views/rails_performance/          # UI templates
│   │   ├── layouts/                      # Shared layouts
│   │   ├── rails_performance/            # Main views
│   │   └── shared/                      # Shared partials
│   └── helpers/rails_performance/        # View helpers
│
├── lib/                        # Core library code
│   └── rails_performance/     # Main gem code
│       ├── models/                    # Data models
│       │   ├── base_record.rb        # Common record interface
│       │   ├── request_record.rb      # HTTP request records
│       │   ├── sidekiq_record.rb     # Sidekiq job records
│       │   ├── delayed_job_record.rb # Delayed::Job records
│       │   ├── grape_record.rb       # Grape API records
│       │   ├── rake_record.rb        # Rake task records
│       │   ├── custom_record.rb      # Custom event records
│       │   ├── resource_record.rb    # System resource records
│       │   └── collection.rb        # Data collection container
│       ├── widgets/                   # UI components
│       │   ├── base.rb               # Widget base class
│       │   ├── table.rb              # Table widget base
│       │   ├── chart.rb              # Chart widget base
│       │   ├── requests_table.rb     # Request data table
│       │   ├── crashes_table.rb      # Crash data table
│       │   ├── throughput_chart.rb   # Throughput visualization
│       │   ├── response_time_chart.rb # Response time chart
│       │   └── [other specific widgets]
│       ├── reports/                   # Data analysis
│       │   ├── base_report.rb        # Report base class
│       │   ├── throughput_report.rb  # Throughput analysis
│       │   ├── response_time_report.rb # Response time analysis
│       │   ├── crash_report.rb       # Crash analysis
│       │   └── [other specific reports]
│       ├── events/                    # Event handling
│       │   └── record.rb             # Event record handling
│       ├── gems/                      # Framework extensions
│       │   ├── sidekiq_ext.rb        # Sidekiq integration
│       │   ├── grape_ext.rb          # Grape API integration
│       │   ├── delayed_job_ext.rb    # Delayed::Job integration
│       │   ├── rake_ext.rb          # Rake task integration
│       │   └── custom_ext.rb        # Custom extension
│       ├── instrument/                # Instrumentation
│       │   └── metrics_collector.rb  # Metrics collection
│       ├── rails/                     # Rails-specific code
│       │   ├── middleware.rb        # Request middleware
│       │   ├── query_builder.rb      # Query composition
│       │   └── middleware_trace_storer_and_cleanup.rb # Trace handling
│       ├── system_monitor/           # System monitoring
│       │   └── resources_monitor.rb  # Resource usage tracking
│       ├── extensions/               # Rails extensions
│       │   ├── trace.rb             # Trace extensions
│       │   ├── view.rb              # View extensions
│       │   └── db.rb                # Database extensions
│       ├── thread/                   # Thread utilities
│       │   └── current_request.rb   # Request context
│       └── data_source.rb           # Query interface
│
├── test/                        # Test suite
│   └── dummy/                    # Dummy Rails app for testing
│       ├── app/                   # Test app structure
│       ├── config/                # Test configuration
│       └── [test files]
│
├── vendor/                      # Third-party code
└── [gem files]
```

## Directory Purposes

**app/controllers/rails_performance/:**
- Purpose: HTTP request handling and UI rendering
- Contains: Controllers for different performance metrics
- Key files: `[base_controller.rb]`, `[rails_performance_controller.rb]`

**lib/rails_performance/models/:**
- Purpose: Data persistence and business logic
- Contains: Record classes for different frameworks
- Key files: `[request_record.rb]`, `[sidekiq_record.rb]`, `[base_record.rb]`

**lib/rails_performance/widgets/:**
- Purpose: UI components for data visualization
- Contains: Table and chart widgets
- Key files: `[base.rb]`, `[table.rb]`, `[requests_table.rb]`

**lib/rails_performance/reports/:**
- Purpose: Data aggregation and analysis
- Contains: Report classes for different metrics
- Key files: `[base_report.rb]`, `[throughput_report.rb]`

**lib/rails_performance/gems/:**
- Purpose: Framework-specific integrations
- Contains: Extensions for Sidekiq, Grape, etc.
- Key files: `[sidekiq_ext.rb]`, `[grape_ext.rb]`

**lib/rails_performance/instrument/:**
- Purpose: Metrics collection
- Contains: Event collectors and middleware
- Key files: `[metrics_collector.rb]`

**app/views/rails_performance/:**
- Purpose: UI templates
- Contains: ERB templates for dashboard
- Key files: `[index.html.erb]`, `[_table.html.erb]`

**test/dummy/:**
- Purpose: Test Rails application
- Contains: Minimal Rails app for integration tests
- Key files: `[config/routes.rb]`, `[app/controllers/home_controller.rb]`

## Key File Locations

**Entry Points:**
- `[lib/rails_performance.rb]`: Main module definition
- `[lib/rails_performance/engine.rb]`: Rails engine initialization
- `[app/controllers/rails_performance/base_controller.rb]`: Base controller with auth

**Configuration:**
- `[lib/rails_performance.rb]`: Module configuration
- `[lib/rails_performance/engine.rb]`: Engine configuration

**Core Logic:**
- `[lib/rails_performance/data_source.rb]`: Query interface
- `[lib/rails_performance/models/request_record.rb]`: Request tracking

**Testing:**
- `[test/]`: Test files
- `[test/dummy/]:` Test application

## Naming Conventions

**Files:**
- Controllers: `*_controller.rb`
- Models: `*_record.rb`
- Widgets: `*_widget.rb` or `*_table.rb`/`*_chart.rb`
- Reports: `*_report.rb`
- Extensions: `*_ext.rb`

**Classes:**
- Controllers: `RailsPerformance::[Name]Controller`
- Models: `RailsPerformance::Models::[Name]Record`
- Widgets: `RailsPerformance::Widgets::[Name]`
- Reports: `RailsPerformance::Reports::[Name]Report`

**Methods:**
- Controllers: snake_case for actions
- Models: snake_case for data methods
- Widgets: snake_case for data methods

## Where to Add New Code

**New Framework Support:**
- Implementation: `[lib/rails_performance/models/[framework]_record.rb]`
- Extensions: `[lib/rails_performance/gems/[framework]_ext.rb]`
- Controllers: Add action in `[rails_performance_controller.rb]`
- Widgets: Add widget in `[lib/rails_performance/widgets/]`
- Views: Add partial in `[app/views/rails_performance/rails_performance/]`

**New Metric Type:**
- Model: Add in `[lib/rails_performance/models/]`
- DataSource: Add query type in `[data_source.rb]`
- Report: Add in `[lib/rails_performance/reports/]`
- Widget: Add widget for visualization

**New UI Component:**
- Widget: Create in `[lib/rails_performance/widgets/]`
- View: Add template in `[app/views/rails_performance/rails_performance/]`
- Controller: Add action to render widget

**Utilities:**
- Shared helpers: `[app/helpers/rails_performance/]`
- Core utilities: `[lib/rails_performance/utils.rb]`

## Special Directories

**lib/rails_performance/gems/:**
- Purpose: Framework integrations
- Generated: No
- Committed: Yes

**test/dummy/:**
- Purpose: Test Rails application
- Generated: Yes (by test setup)
- Committed: Yes

**app/engine_assets/:**
- Purpose: Isolated assets for the engine
- Generated: No
- Committed: Yes
- Special: Uses isolate_assets for isolation

---

*Structure analysis: 2026-02-04*