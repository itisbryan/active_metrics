# Phase 1: Redis SCAN Migration - Research

**Researched:** 2026-02-06
**Domain:** Redis key iteration optimization (Ruby/Rails)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Feature flag strategy**
- Shield new SCAN code behind flag; KEYS runs by default when flag off
- Permanent long-term flag (safety valve, never removed)
- Flag configured via gem configuration: `RailsPerformance.use_scan = true/false`
- Add deprecation warning when KEYS path is used, guiding users to SCAN

**SCAN COUNT tuning**
- Default COUNT value: 10 (Redis default)
- Auto-tune COUNT per query type (researcher to determine optimal values)
- Configuration option named `scan_count`
- Warn if COUNT value is extreme (<1 or >10000)

**Backwards compatibility**
- Strict breaking change bar: any difference in behavior is breaking
- Must preserve key order: sort SCAN results to match KEYS order
- Deprecate KEYS path with warning, keep available indefinitely via flag
- Minor/patch version change (1.x), not major version bump

**Performance validation**
- Success metric: Both non-blocking AND performance parity vs KEYS
- Test all dataset sizes: small (100s), medium (1,000s), large (10,000s)
- Critical test: Verify SCAN doesn't block other Redis operations
- Benchmark script: Ruby script committed to repo, run on demand

### Claude's Discretion

- Exact auto-tuning algorithm for COUNT per query type
- Timeout duration specifics (within "medium" 10-30 second range)
- Retry backoff strategy for SCAN timeouts
- CI benchmark thresholds and regression detection
- Error message format (minimal, as specified)

### Deferred Ideas (OUT OF SCOPE)

None - discussion stayed within phase scope.
</user_constraints>

## Summary

This phase replaces the blocking Redis KEYS command with non-blocking SCAN iteration throughout the rails_performance gem. The current implementation in `lib/rails_performance/utils.rb:33` uses `redis.keys(query)` which blocks the entire Redis server during execution - a critical production safety issue for applications with large keyspaces.

The research confirms that SCAN is the production-standard replacement for KEYS, available in Redis since 2.8.0 and fully supported by the redis-rb gem (current dependency: any version, using 5.4.1). The redis-rb gem provides both `scan` (manual cursor management) and `scan_each` (Enumerator-based) methods for iteration.

Key implementation requirements include: (1) feature flag controlled migration with KEYS as default fallback, (2) configurable COUNT parameter with auto-tuning per query type, (3) sorted results to match KEYS order for backwards compatibility, (4) deprecation warnings when KEYS path is used, and (5) comprehensive performance testing across dataset sizes.

**Primary recommendation:** Implement SCAN using redis-rb's `scan_each` with a configurable COUNT parameter, wrapped in a feature flag that defaults to KEYS, with deprecation warnings guiding users to enable SCAN.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **redis-rb** | 5.4.1+ | Ruby Redis client | Gem's current dependency; provides `scan`, `scan_each` methods with proper SCAN support |
| **Redis SCAN** | 2.8.0+ | Non-blocking key iteration | Official replacement for KEYS command; incremental iteration prevents blocking production Redis servers |
| **Redis** | 2.8.0+ | Data store | SCAN available since Redis 2.8.0 (2013); all production Redis instances support SCAN |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **redis-client** | 0.22.0+ | Low-level Ruby Redis client | Underlying client used by redis-rb; supports SCAN commands |
| **benchmark-ips** | Latest | Ruby performance benchmarking | Measure iterations per second for KEYS vs SCAN comparison |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| **SCAN** | KEYS | Never in production - KEYS blocks entire Redis server during keyspace scan |
| **scan_each** | Manual cursor loop with `scan` | scan_each is cleaner Ruby-idiomatic; manual scan provides more control over iteration |
| **Feature flag gradual rollout** | Big bang replacement | Gradual rollout reduces risk; flag provides safety valve if SCAN issues arise |

**Installation:**
```bash
# Already installed via rails_performance.gemspec
# Current: redis gem (any version, currently using 5.4.1)
# No additional installation needed
```

## Architecture Patterns

### Recommended Project Structure
```
lib/rails_performance/
├── utils.rb                    # Add SCAN implementation here (modify fetch_from_redis)
├── rails_performance.rb         # Add use_scan and scan_count configuration
└── gems/
    └── grape_ext.rb            # Verify Grape API compatibility (no KEYS usage)

test/
├── utils_test.rb               # Add SCAN tests
├── benchmark/
│   └── redis_scan_benchmark.rb # New: performance comparison script
└── redis_scan_test.rb          # New: integration tests for SCAN vs KEYS

docs/
└── SCAN_MIGRATION.md           # New: feature flag and rollout guide
```

### Pattern 1: Feature Flag Configuration with mattr_accessor

**What:** Rails gem configuration pattern using class-level accessors with setup block

**When to use:** Configuring Rails engine/gem behavior via initializer

**Example:**
```ruby
# lib/rails_performance.rb
module RailsPerformance
  mattr_accessor :use_scan
  @@use_scan = false  # Default: KEYS (backwards compatible)

  mattr_accessor :scan_count
  @@scan_count = 10  # Redis default

  mattr_accessor :scan_count_auto_tune
  @@scan_count_auto_tune = true

  def self.setup
    yield(self)
  end
end

# Usage in config/initializers/rails_performance.rb
RailsPerformance.setup do |config|
  config.use_scan = true
  config.scan_count = 100
  config.scan_count_auto_tune = false
end
```

**Source:** [Rails Guides - Engines](https://guides.rubyonrails.org/engines.html) - Official Rails engine configuration pattern

### Pattern 2: SCAN Implementation with scan_each

**What:** Replace redis.keys(query) with redis.scan_each(match: query).to_a

**When to use:** Non-blocking key iteration in production

**Example:**
```ruby
# lib/rails_performance/utils.rb
def self.fetch_from_redis(query)
  RailsPerformance.log "\n\n   [REDIS QUERY]   -->   #{query}\n\n"

  if RailsPerformance.use_scan
    keys = fetch_with_scan(query)
  else
    RailsPerformance.log "   [DEPRECATION] Using KEYS command. Set RailsPerformance.use_scan = true to use non-blocking SCAN.\n"
    keys = RailsPerformance.redis.keys(query)
  end

  return [] if keys.blank?

  values = RailsPerformance.redis.mget(keys)

  RailsPerformance.log "\n\n   [FOUND]   -->   #{values.size}\n\n"

  [keys, values]
end

def self.fetch_with_scan(query)
  count = determine_scan_count(query)

  keys = RailsPerformance.redis.scan_each(
    match: query,
    count: count
  ).to_a.sort  # Sort to match KEYS order

  keys
end

def self.determine_scan_count(query)
  return RailsPerformance.scan_count unless RailsPerformance.scan_count_auto_tune

  # Auto-tune based on query type
  case query
  when /datetime|\d{8}/  # Date-scoped query
    1000  # Larger COUNT for date queries
  when /request_id/      # Specific request lookup
    10   # Smaller COUNT for specific queries
  else                   # Broad queries
    100  # Medium COUNT for general queries
  end
end
```

**Source:** [redis-rb source code](https://github.com/redis/redis-rb/blob/master/lib/redis/commands/keys.rb) - Official scan_each implementation

### Pattern 3: Deprecation Warning with ActiveSupport::Deprecation

**What:** Emit deprecation warnings using ActiveSupport::Deprecation.warn

**When to use:** Warning users about deprecated code paths

**Example:**
```ruby
require 'active_support/deprecation'

# In utils.rb, when KEYS path is used
unless RailsPerformance.use_scan
  deprecator = ActiveSupport::Deprecation.new('2.0', 'RailsPerformance')
  deprecator.warn("Using Redis KEYS command is deprecated. Set RailsPerformance.use_scan = true to use non-blocking SCAN.")
end
```

**Note:** As of Rails 7.1+, gem authors should create their own deprecator instance rather than using the global `ActiveSupport::Deprecation.warn`.

**Source:** [Rails 7.1 Release Notes](https://www.gitclear.com/open_repos/rails/rails/release/v7.1.0.beta1?page=20) - Gem deprecation pattern

### Pattern 4: Redis SCAN COUNT Auto-tuning

**What:** Adjust COUNT parameter based on query type for optimal performance

**When to use:** Different query patterns have different optimal batch sizes

**Example:**
```ruby
# Query types from lib/rails_performance/data_source.rb
# - Date-scoped: "performance|*datetime|20260204*|*|END|1.0.0"
# - Request ID: "performance|*|request_id|xyz|*"
# - Controller/action: "performance|*controller|HomeController|action|index*|END|1.0.0"

SCAN_COUNT_DEFAULTS = {
  date_scoped: 1000,      # Large COUNT for date ranges (more keys per batch)
  specific_lookup: 10,    # Small COUNT for specific lookups (fewer keys expected)
  broad_query: 100        # Medium COUNT for general queries
}.freeze

def self.determine_scan_count(query)
  return RailsPerformance.scan_count unless RailsPerformance.scan_count_auto_tune

  if query.include?('datetime') && query.include?('*')
    # Date wildcard query like "datetime|20260204*"
    SCAN_COUNT_DEFAULTS[:date_scoped]
  elsif query.include?('request_id')
    # Specific request lookup
    SCAN_COUNT_DEFAULTS[:specific_lookup]
  else
    # General controller/action/status queries
    SCAN_COUNT_DEFAULTS[:broad_query]
  end
end
```

**Source:** [Redis SCAN COUNT Best Practices](https://stackoverflow.com/questions/43146978/redis-scan-count-in-production) - COUNT tuning guidance

### Anti-Patterns to Avoid

- **Using KEYS in production**: Blocks entire Redis server; causes production outages with large keyspaces
- **Assuming SCAN returns all keys in one call**: SCAN is cursor-based; requires iteration until cursor returns to "0"
- **Not sorting SCAN results**: SCAN doesn't guarantee order; KEYS returns sorted results - must sort for backwards compatibility
- **Ignoring duplicate detection**: SCAN may return duplicate keys; use Set or handle duplicates in application logic
- **Setting COUNT too high**: Very high COUNT values (>10000) can cause long-running SCAN calls; warn users of extreme values

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| **Redis cursor management** | Manual cursor loop with while/break | `redis.scan_each` | scan_each handles cursor iteration, returns Enumerator, Ruby-idiomatic |
| **Deduplication logic** | Custom duplicate detection code | `keys.uniq` or Set | SCAN may return duplicates; Ruby's uniq handles this efficiently |
| **Benchmarking framework** | Custom timing code with Time.now | `benchmark-ips` gem | Standard Ruby benchmarking library; measures iterations per second accurately |
| **Deprecation warnings** | Kernel.warn or custom logger | `ActiveSupport::Deprecation` | Standard Rails deprecation system; integrates with Rails logging and testing |

**Key insight:** The redis-rb gem already provides production-tested SCAN implementation via `scan_each`. Building manual cursor management adds complexity and risk for no benefit.

## Common Pitfalls

### Pitfall 1: SCAN Returns Results in Different Order Than KEYS

**What goes wrong:** Tests fail because SCAN returns keys in arbitrary order, while KEYS returns sorted keys. Existing code may depend on sorted order.

**Why it happens:** SCAN iterates Redis keyspace incrementally based on hash table structure, not lexicographic order. KEYS sorts all keys before returning.

**How to avoid:** Always sort SCAN results before returning: `keys.sort`. This ensures backwards compatibility with KEYS behavior.

**Warning signs:** Test failures after SCAN migration where key order matters, assertions about "first" or "last" keys failing.

### Pitfall 2: SCAN May Return Duplicate Keys

**What goes wrong:** Application processes same key multiple times, or reports incorrect counts (more keys than actually exist).

**Why it happens:** SCAN guarantees all elements present from start to end are returned, but elements may be returned multiple times during rehashing.

**How to avoid:** Deduplicate results: `keys.uniq` or convert to Set: `Set.new(keys)`. The redis-rb `scan_each` method may return duplicates.

**Warning signs:** Count mismatches (SCAN returns more keys than exist), duplicate entries in reports, duplicate processing in loops.

### Pitfall 3: COUNT Parameter is a Hint, Not a Guarantee

**What goes wrong:** Assuming COUNT=100 means exactly 100 keys returned per call, or that SCAN will complete in N/COUNT iterations.

**Why it happens:** Redis COUNT is a "hint for the amount of work to be done" per iteration, not a strict limit on results. Actual returned count may vary.

**How to avoid:** Don't make assumptions about iteration count based on COUNT. Use cursor=0 as termination condition, not empty arrays.

**Warning signs:** Infinite loops, unexpected iteration counts, logic that depends on specific batch sizes.

### Pitfall 4: Empty Array Doesn't Mean SCAN is Complete

**What goes wrong:** Terminating SCAN loop when batch_keys is empty, missing keys that exist in Redis.

**Why it happens:** SCAN may return empty batches even when more keys exist. Only cursor="0" indicates completion.

**How to avoid:** Always check cursor value: `break if cursor == "0"`. Don't use `break if batch_keys.empty?`.

**Warning signs:** Missing data in queries, incomplete result sets, intermittent test failures.

### Pitfall 5: Feature Flag Defaults Cause Immediate Production Impact

**What goes wrong:** Feature flag defaults to `true`, enabling SCAN in production without testing, causing unexpected behavior or performance issues.

**Why it happens:** New code often defaults to "enabled" for immediate adoption, but infrastructure changes need gradual rollout.

**How to avoid:** Default feature flag to `false` (KEYS behavior), require explicit opt-in for SCAN. This ensures backwards compatibility and controlled rollout.

**Warning signs:** Production incidents after deployment, sudden performance changes, unexpected error messages.

### Pitfall 6: Not Testing with Production-like Dataset Sizes

**What goes wrong:** SCAN works fine in development with 100 keys, but has issues in production with 10,000+ keys (timeouts, memory issues, slow iteration).

**Why it happens:** Development environments typically have much smaller datasets than production. SCAN performance characteristics differ at scale.

**How to avoid:** Test with three dataset sizes: small (100s), medium (1,000s), large (10,000s). Use benchmark script to measure performance at each scale.

**Warning signs:** "Works on my machine" issues, production-only bugs, timeouts in production but not development.

### Pitfall 7: SCAN Blocks Longer Than Expected with Large COUNT

**What goes wrong:** Setting COUNT=10000 to reduce round-trips, but individual SCAN calls take multiple seconds, partially defeating the non-blocking goal.

**Why it happens:** COUNT is a "work hint," not a result limit. Large COUNT values can cause longer individual calls even though overall iteration may be faster.

**How to avoid:** Use moderate COUNT values (10-1000 for most cases). Warn users if COUNT > 10000. Test different COUNT values with benchmark script.

**Warning signs:** Slow individual SCAN calls, Redis latency spikes during SCAN operations, timeout errors.

## Code Examples

Verified patterns from official sources:

### Using scan_each for Non-Blocking Iteration

```ruby
# Source: https://github.com/redis/redis-rb/blob/master/lib/redis/commands/keys.rb
# SCAN with scan_each returns Enumerator of keys

def self.fetch_from_redis(query)
  # Use scan_each with MATCH pattern
  keys = RailsPerformance.redis.scan_each(match: query, count: 100).to_a

  # Sort to match KEYS behavior (backwards compatibility)
  keys.sort!

  return [] if keys.blank?

  values = RailsPerformance.redis.mget(keys)

  [keys, values]
end
```

### Manual SCAN with Cursor Loop

```ruby
# Source: https://redis.io/docs/latest/commands/scan/
# Manual cursor management for more control

def self.fetch_from_redis_manual(query)
  keys = []
  cursor = "0"

  loop do
    cursor, batch_keys = RailsPerformance.redis.scan(
      cursor,
      match: query,
      count: 100
    )

    keys.concat(batch_keys)

    break if cursor == "0"
  end

  keys.sort!  # Maintain KEYS ordering
  keys.uniq!  # Remove SCAN duplicates

  values = RailsPerformance.redis.mget(keys)

  [keys, values]
end
```

### Feature Flag Pattern

```ruby
# Source: Rails Engines Guide
# https://guides.rubyonrails.org/engines.html

module RailsPerformance
  mattr_accessor :use_scan
  @@use_scan = false

  mattr_accessor :scan_count
  @@scan_count = 10

  def self.setup
    yield(self)
  end
end

# Usage in initializer
RailsPerformance.setup do |config|
  config.use_scan = true
  config.scan_count = 100
end
```

### COUNT Value Validation

```ruby
# Validate SCAN COUNT is within reasonable bounds
def self.validate_scan_count(count)
  if count < 1
    raise ArgumentError, "scan_count must be >= 1, got #{count}"
  end

  if count > 10_000
    RailsPerformance.log "[WARNING] scan_count (#{count}) is very high. This may cause long-running SCAN calls. Recommended range: 1-1000."
  end
end
```

### Benchmark Script Template

```ruby
# Source: https://www.johnnunemaker.com/how-to-benchmark-your-ruby-gem/
# Using benchmark-ips gem

require 'benchmark/ips'
require 'redis'

# Configure Redis
redis = Redis.new

# Setup test data
test_keys = 1000.times.map { |i| "performance|test|key#{i}" }
test_keys.each { |k| redis.set(k, "value") }

Benchmark.ips do |x|
  x.report("KEYS") do
    redis.keys("performance|test|*")
  end

  x.report("SCAN (count=10)") do
    redis.scan_each(match: "performance|test|*", count: 10).to_a
  end

  x.report("SCAN (count=100)") do
    redis.scan_each(match: "performance|test|*", count: 100).to_a
  end

  x.compare!
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| **KEYS command** | **SCAN command** | Redis 2.8.0 (2013) | SCAN is non-blocking; KEYS deprecated for production use |
| **Global ActiveSupport::Deprecation.warn** | **Per-gem deprecator instances** | Rails 7.1 (2024) | Gems must create own deprecator; global singleton deprecated |
| **Manual cursor loops** | **scan_each Enumerator** | redis-rb 4.0+ | Cleaner Ruby-idiomatic code; easier to read and maintain |

**Deprecated/outdated:**
- **KEYS command in production**: Blocks entire Redis server; use SCAN instead
- **ActiveSupport::Deprecation.warn (singleton)**: Deprecated in Rails 7.1, will be removed in Rails 7.2; use custom deprecator
- **Assuming KEYS sorting order**: SCAN returns unsorted; must explicitly sort for backwards compatibility

## Open Questions

1. **Exact auto-tuning algorithm for COUNT per query type**
   - What we know: Date-scoped queries need higher COUNT (1000), specific lookups need lower COUNT (10)
   - What's unclear: Optimal COUNT values for different query patterns based on real-world data distribution
   - Recommendation: Start with conservative defaults (10/100/1000), measure with benchmark script, adjust based on real usage data

2. **Timeout duration specifics**
   - What we know: User specified "medium" 10-30 second range
   - What's unclear: Whether to use Ruby timeout, Redis client timeout, or custom timeout handling
   - Recommendation: Use redis-rb's built-in timeout configuration (default: few seconds), document that SCAN operations should complete quickly

3. **Retry backoff strategy for SCAN timeouts**
   - What we know: SCAN operations can timeout with large datasets or high COUNT values
   - What's unclear: Whether to retry with lower COUNT, abort immediately, or log and continue
   - Recommendation: For initial implementation, log timeout and fall back to KEYS with warning. Future phases can add retry logic.

4. **CI benchmark thresholds and regression detection**
   - What we know: Need to measure KEYS vs SCAN performance parity
   - What's unclear: Acceptable performance regression threshold (e.g., SCAN can be 20% slower but must be non-blocking)
   - Recommendation: Set initial threshold at "SCAN must be within 2x of KEYS performance" and non-blocking. Adjust based on real measurements.

5. **Error message format**
   - What we know: User specified "minimal" error messages
   - What's unclear: Whether to use Rails logger, stdout, or raise exceptions
   - Recommendation: Use RailsPerformance.log for consistency with existing code, minimal messages like "[SCAN ERROR] timeout"

## Sources

### Primary (HIGH confidence)

- **[Redis SCAN Documentation](https://redis.io/docs/latest/commands/scan/)** - Official Redis 8.4 docs with SCAN guarantees, MATCH/COUNT options, complexity analysis (verified 2026-02-06)
- **[redis-rb source code - lib/redis/commands/keys.rb](https://github.com/redis/redis-rb/blob/master/lib/redis/commands/keys.rb)** - Actual Ruby gem implementation showing `scan`, `scan_each` methods
- **[Rails Guides - Engines](https://guides.rubyonrails.org/engines.html)** - Official Rails engine configuration patterns using mattr_accessor
- **[Redis Performance Tuning Best Practices](https://redis.io/faq/doc/1mebipyp1e/performance-tuning-best-practices)** - Official Redis performance guidance

### Secondary (MEDIUM confidence)

- **[How to Analyze Redis Keyspace with SCAN](https://oneuptime.com/blog/post/2026-01-21-redis-analyze-keyspace-scan/view)** - 2026 comprehensive SCAN guide
- **[Redis Scan Count in production](https://stackoverflow.com/questions/43146978/redis-scan-count-in-production)** - Production COUNT tuning discussion
- **[Faster KEYS and SCAN: Optimized glob-style patterns](https://redis.io/blog/faster-keys-and-scan-optimized/)** - Redis 8.4 SCAN performance improvements
- **[How to Benchmark Your Ruby Gem](https://www.johnnunemaker.com/how-to-benchmark-your-ruby-gem/)** - Benchmark-ips usage for Ruby gems
- **[Making Your Ruby Gem Configurable](https://dev.to/rwehresmann/making-your-ruby-gem-configurable-1k16)** - mattr_accessor configuration pattern
- **[Rails 7.1 Deprecation Changes](https://www.gitclear.com/open_repos/rails/rails/release/v7.1.0.beta1?page=20)** - ActiveSupport::Deprecation.warn deprecation
- **[redis-rb/redis-client](https://github.com/redis-rb/redis-client)** - Redis timeout handling in Ruby (ReadTimeoutError)
- **[How to rescue timeout issues (Ruby, Rails)](https://stackoverflow.com/questions/2370140/how-to-rescue-timeout-issues-ruby-rails)** - Ruby timeout exception handling
- **[Redis Best Practices](https://www.dragonflydb.io/guides/redis-best-practices)** - Error handling and retry mechanisms

### Tertiary (LOW confidence)

- **[Redis KEYS vs SCAN - Medium](https://medium.com/@shaskumar/redis-scan-vs-keys-command-9df7f51b7162)** - Performance comparison (verified with official docs)
- **[How to Safely Navigate Redis with Ruby](https://dev.to/molly/how-to-safely-navigate-redis-with-ruby-j9l)** - General Ruby Redis best practices
- **[ruby redis client scan vs keys - StackOverflow](https://stackoverflow.com/questions/22143659/ruby-redis-client-scan-vs-keys)** - Ruby-specific SCAN discussion

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Redis SCAN and redis-rb are production-standard, well-documented
- Architecture: HIGH - All patterns verified with official sources (Redis docs, redis-rb source, Rails guides)
- Pitfalls: HIGH - SCAN behavior well-documented; common issues known from Redis community
- Implementation details: MEDIUM - Auto-tuning algorithms and timeout handling require real-world testing

**Research date:** 2026-02-06
**Valid until:** 2026-03-06 (30 days - Redis SCAN API is stable, but Ruby gem patterns may evolve)

**Key takeaways for planning:**
1. Use redis-rb's `scan_each` method for cleaner implementation
2. Implement feature flag defaulting to KEYS (false) for backwards compatibility
3. Sort SCAN results to match KEYS order
4. Auto-tune COUNT based on query type (date-scoped vs specific vs broad)
5. Create comprehensive benchmark script for validation
6. Add deprecation warnings when KEYS path is used
7. Test with small (100s), medium (1,000s), large (10,000s) datasets
8. Document feature flag usage and migration path for users
