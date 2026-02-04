# Stack Research: Redis Best Practices for Rails Performance

**Domain:** Redis KEYS to SCAN migration for Rails Performance gem
**Researched:** 2026-02-04
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Redis SCAN** | 2.8.0+ | Non-blocking key iteration | Official replacement for KEYS command; incremental iteration prevents blocking production Redis servers |
| **redis-rb** | 5.4.1+ | Ruby Redis client | Gem's current dependency; provides `scan`, `scan_each` methods with proper SCAN support |
| **redis-client** | 0.22.0+ | Low-level Ruby Redis client | Underlying client used by redis-rb; supports SCAN commands |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **redis-rb** | 5.4.1 | Ruby Redis client wrapper | Already in use; provides `scan_each` enumerator for clean iteration |
| **Match patterns** | Native | Pattern-based key filtering | Use `MATCH` with SCAN for time-series key pattern queries |

## Installation

```bash
# Already installed via rails_performance.gemspec
# Current: redis gem (any version, currently using 5.4.1)
# No additional installation needed
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| **SCAN** | KEYS | Never in production - KEYS blocks entire Redis server during keyspace scan |
| **SCAN with COUNT** | Default SCAN (COUNT=10) | When you need larger batches per iteration for performance tuning |
| **scan_each** | Manual cursor loop | When you prefer Enumerator-based iteration over manual cursor management |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **KEYS command** | Blocks Redis server for duration of scan; can halt production with large keyspaces | SCAN command |
| **Unbounded SCAN loops** | May never terminate if dataset grows faster than iteration | Set reasonable COUNT values or use `scan_each` with breaks |
| **MATCH without cursor checks** | MATCH filter applied AFTER retrieval; can return empty arrays multiple times | Use cursor=0 termination check, not empty arrays |

## Stack Patterns by Variant

**If replacing `redis.keys(query)`:**
- Use `redis.scan(match: query, count: 100)` with cursor loop
- Because: Maintains same pattern matching capability without blocking

**If iterating time-series data by date:**
- Use `redis.scan(match: "performance|*|datetime|20260204*|*", count: 1000)`
- Because: Larger COUNT values reduce round-trips for date-scoped queries

**If backwards compatibility critical:**
- Keep existing key pattern format: `performance|controller|HomeController|action|index|...`
- Because: SCAN doesn't require key format changes; only changes iteration method

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| redis gem 5.4.1 | redis-client 0.22.0+ | Current setup; SCAN commands fully supported |
| redis gem 5.0+ | Redis 2.8.0+ | SCAN available since Redis 2.8.0 |
| redis gem 4.0+ | Redis 2.8.0+ | SCAN available; `scan_each` enumerator available |

## Implementation Strategy

### Current KEYS Usage (lib/rails_performance/utils.rb:30-41)

```ruby
def self.fetch_from_redis(query)
  RailsPerformance.log "\n\n   [REDIS QUERY]   -->   #{query}\n\n"

  keys = RailsPerformance.redis.keys(query)  # ❌ BLOCKING
  return [] if keys.blank?

  values = RailsPerformance.redis.mget(keys)

  RailsPerformance.log "\n\n   [FOUND]   -->   #{values.size}\n\n"

  [keys, values]
end
```

### Recommended SCAN Replacement

```ruby
def self.fetch_from_redis(query)
  RailsPerformance.log "\n\n   [REDIS QUERY]   -->   #{query}\n\n"

  keys = []
  cursor = "0"

  # Non-blocking SCAN iteration
  loop do
    cursor, batch_keys = RailsPerformance.redis.scan(
      cursor,
      match: query,
      count: 100  # Tune based on key size
    )

    keys.concat(batch_keys)
    break if cursor == "0"
  end

  return [] if keys.blank?

  values = RailsPerformance.redis.mget(keys)

  RailsPerformance.log "\n\n   [FOUND]   -->   #{values.size}\n\n"

  [keys, values]
end
```

### Alternative: Using scan_each (Cleaner, Ruby-idiomatic)

```ruby
def self.fetch_from_redis(query)
  RailsPerformance.log "\n\n   [REDIS QUERY]   -->   #{query}\n\n"

  keys = RailsPerformance.redis.scan_each(match: query).to_a

  return [] if keys.blank?

  values = RailsPerformance.redis.mget(keys)

  RailsPerformance.log "\n\n   [FOUND]   -->   #{values.size}\n\n"

  [keys, values]
end
```

## Key Pattern Maintenance for Time-Series Data

### Current Key Pattern (from lib/rails_performance/models/request_record.rb:118)

```
performance|controller|HomeController|action|index|format|html|status|200|datetime|20260204T0523|datetimei|1579861423|method|GET|path|/|request_id|454545454545454545|END|1.0.0
```

### SCAN Patterns for Time-Series Queries

**Query Pattern for Date Range (from lib/rails_performance/data_source.rb:84):**
```ruby
"performance|*#{compile_requests_query}*|END|#{RailsPerformance::SCHEMA}"
# Expands to: "performance|*controller|HomeController|action|index|*datetime|20260204*|*END|1.0.0"
```

**SCAN Implementation:**
```ruby
# All keys for specific date
cursor = "0"
pattern = "performance|*datetime|20260204*|*|END|#{RailsPerformance::SCHEMA}"

loop do
  cursor, keys = redis.scan(cursor, match: pattern, count: 1000)
  # Process keys
  break if cursor == "0"
end
```

### Backwards Compatibility Considerations

**No key format changes required:**
- Existing keys remain: `performance|controller|...|datetime|YYYYMMDD*|...|END|1.0.0`
- SCAN patterns match same glob-style patterns as KEYS
- Migration is transparent to existing data

**Migration approach:**
1. Replace `redis.keys(query)` with SCAN implementation
2. No data migration needed
3. Existing queries work unchanged
4. Gradual rollout possible (feature flag)

## Performance Characteristics

### KEYS vs SCAN Comparison

| Aspect | KEYS | SCAN |
|--------|------|------|
| **Blocking** | Yes - entire keyspace | No - incremental |
| **Time Complexity** | O(N) single call | O(1) per call, O(N) complete iteration |
| **Production Safe** | ❌ No | ✅ Yes |
| **Memory** | Returns all keys at once | Returns batch (10 default) |
| **Network Round-trips** | 1 | Multiple (until cursor=0) |
| **Duplicate Detection** | Not needed | Required (elements may repeat) |

### SCAN Guarantees (from Redis docs)

- A full iteration retrieves all elements present from start to end
- Never returns elements not present during entire iteration
- Elements may be returned **multiple times** (application should deduplicate)
- Elements added/removed during iteration: undefined behavior

### Optimization Tips for Rails Performance

**For time-series date queries:**
```ruby
# Use larger COUNT for date-scoped queries
redis.scan(cursor, match: date_pattern, count: 1000)
```

**For broad queries (all requests):**
```ruby
# Use default COUNT to avoid overwhelming response
redis.scan(cursor, match: "performance|*|*|END|1.0.0", count: 10)
```

**For specific queries (controller/action):**
```ruby
# Tighter pattern reduces iterations needed
redis.scan(cursor, match: "performance|*controller|HomeController|action|index*|END|1.0.0")
```

## Sources

- **[Redis Official SCAN Documentation](https://redis.io/docs/latest/commands/scan/)** — HIGH confidence: Official Redis 8.4 docs with SCAN guarantees, MATCH/COUNT options, complexity analysis (verified 2026-01-30)
- **[Redis KEYS vs SCAN - Medium](https://medium.com/@shaskumar/redis-scan-vs-keys-command-9df7f51b7162)** — MEDIUM confidence: Performance comparison for production use cases
- **[Redis KEYS * vs SCAN - Medium](https://osvaldo-gonzalez-venegas.medium.com/redis-keys-vs-scan-whats-the-real-difference-e0d72173221c)** — MEDIUM confidence: Production safety recommendations
- **[ruby redis client scan vs keys - StackOverflow](https://stackoverflow.com/questions/22143659/ruby-redis-client-scan-vs-keys)** — MEDIUM confidence: Ruby-specific SCAN discussion
- **[redis-rb source code - lib/redis/commands/keys.rb](https://github.com/redis/redis-rb/blob/master/lib/redis/commands/keys.rb)** — HIGH confidence: Actual Ruby gem implementation showing `scan`, `scan_each` methods
- **[How to Safely Navigate Redis with Ruby - dev.to](https://dev.to/molly/how-to-safely-navigate-redis-with-ruby-j9l)** — LOW confidence: General Ruby Redis best practices

---
*Stack research for: Rails Performance Redis KEYS to SCAN migration*
*Researched: 2026-02-04*
