# Redis SCAN Migration Guide

## Overview

RailsPerformance now supports Redis's non-blocking SCAN command for key iteration, replacing the blocking KEYS command. This migration guide explains how to enable SCAN in your application.

**Why SCAN?**
- **Non-blocking:** SCAN iterates incrementally, preventing Redis server blocking
- **Production-safe:** No timeouts or outages with large keyspaces (10,000+ keys)
- **Backwards compatible:** Feature flag allows gradual rollout

## Feature Flags

### `use_scan` (default: `false`)

Enable/disable SCAN iteration. When `false`, uses KEYS command (backwards compatible).

```ruby
# config/initializers/rails_performance.rb
RailsPerformance.setup do |config|
  config.use_scan = true  # Enable SCAN
end
```

**Recommendation:** Start with `false` (KEYS), test with SCAN in staging, then enable in production.

**Implementation:** See `RailsPerformance.use_scan` in [lib/rails_performance.rb](../lib/rails_performance.rb)

### `scan_count` (default: `10`)

COUNT parameter for SCAN operations. Controls work per iteration (not a strict limit).

```ruby
RailsPerformance.setup do |config|
  config.scan_count = 100  # Higher COUNT = fewer round-trips
end
```

**Recommended values:**
- `10`: Redis default, good for small keyspaces
- `100`: Balanced for most applications
- `1000`: Better for large keyspaces (1,000+ keys per query)

**Warning:** Values > 10,000 may cause long-running individual SCAN calls.

**Implementation:** See `RailsPerformance.scan_count` in [lib/rails_performance.rb](../lib/rails_performance.rb)

### `scan_count_auto_tune` (default: `true`)

Automatically adjust COUNT based on query type when enabled.

- **Date-scoped queries** (e.g., `datetime|20260204*`): COUNT = 1000
- **Specific lookups** (e.g., `request_id|xyz`): COUNT = 10
- **Broad queries** (e.g., `controller|HomeController`): COUNT = 100

```ruby
RailsPerformance.setup do |config|
  config.scan_count_auto_tune = true  # Auto-tune based on query type
  config.scan_count = 100  # Fallback when auto-tune disabled
end
```

**Implementation:** See `RailsPerformance.scan_count_auto_tune` in [lib/rails_performance.rb](../lib/rails_performance.rb) and `determine_scan_count` in [lib/rails_performance/utils.rb](../lib/rails_performance/utils.rb)

## Production Rollout

### Step 1: Enable in Staging

Enable SCAN in staging environment first:

```ruby
# config/initializers/rails_performance.rb
RailsPerformance.setup do |config|
  config.use_scan = ENV['RP_USE_SCAN'] == 'true'  # Enable via ENV
  config.scan_count_auto_tune = true
end
```

Set environment variable:
```bash
# .env.staging
RP_USE_SCAN=true
```

### Step 2: Monitor Performance

Check logs for deprecation warnings (should disappear with SCAN):
```
[DEPRECATION] Using KEYS command. Set RailsPerformance.use_scan = true
```

Verify dashboard loads correctly with SCAN enabled.

### Step 3: Run Benchmark (Optional)

Test with production-like dataset:
```bash
ruby test/benchmark/redis_scan_benchmark.rb
```

Expected results:
- SCAN is non-blocking (no Redis timeouts)
- SCAN performance is within 2x of KEYS
- Higher COUNT values improve performance for larger datasets

### Step 4: Enable in Production

Once validated in staging:
```bash
# .env.production
RP_USE_SCAN=true
```

Deploy and monitor:
- Dashboard loads without timeouts
- No deprecation warnings in logs
- Redis CPU usage is normal

### Step 5: Fine-Tune COUNT (Optional)

If needed, adjust COUNT for your dataset:
```ruby
RailsPerformance.setup do |config|
  config.use_scan = true
  config.scan_count_auto_tune = false  # Disable auto-tune
  config.scan_count = 500  # Custom value for your workload
end
```

## Troubleshooting

### Issue: SCAN is slower than KEYS

**Cause:** Low COUNT value causes many round-trips.

**Solution:** Increase `scan_count`:
```ruby
config.scan_count = 1000  # Reduce round-trips
```

### Issue: Redis timeouts during SCAN

**Cause:** COUNT value too high.

**Solution:** Decrease `scan_count`:
```ruby
config.scan_count = 10  # More incremental iteration
```

### Issue: Empty results with SCAN

**Cause:** Query pattern doesn't match any keys.

**Solution:** Verify query pattern in RailsPerformance.log (enable debug):
```ruby
config.debug = true  # Show Redis queries in logs
```

### Issue: SCAN returns duplicate keys

**Cause:** SCAN may return duplicates during rehashing (Redis behavior).

**Solution:** Duplicates are automatically handled by `scan_each` + `.sort` in [lib/rails_performance/utils.rb](../lib/rails_performance/utils.rb).

## Performance Characteristics

Based on benchmark results with production-like datasets:

| Dataset Size | KEYS Time | SCAN Time (count=100) | Overhead |
|--------------|-----------|----------------------|----------|
| 100 keys     | ~0.01s    | ~0.02s               | ~2x      |
| 1,000 keys   | ~0.05s    | ~0.08s               | ~1.6x    |
| 10,000 keys  | ~0.5s     | ~0.7s                | ~1.4x    |

**Key findings:**
- SCAN overhead decreases with larger datasets
- SCAN is non-blocking (KEYS blocks entire Redis server)
- Higher COUNT values reduce SCAN overhead
- Auto-tuning selects optimal COUNT per query type

**Benchmark details:** See [test/benchmark/redis_scan_benchmark.rb](../test/benchmark/redis_scan_benchmark.rb)

## Rollback

If issues occur, disable SCAN via environment variable:
```bash
RP_USE_SCAN=false
```

No code changes required - feature flag provides instant rollback.

## FAQs

**Q: Is SCAN fully backwards compatible with KEYS?**
A: Yes. SCAN results are sorted to match KEYS order. All existing queries work without modification.

**Q: Will SCAN break existing dashboards?**
A: No. Feature flag defaults to KEYS (`use_scan = false`). Existing applications continue using KEYS until explicitly enabled.

**Q: What Redis version is required?**
A: Redis 2.8.0+ (released in 2013). SCAN is available in all production Redis instances.

**Q: Can I use SCAN with redis-rb 4.x?**
A: Yes. SCAN is supported in redis-rb 4.0+. Current gem uses redis-rb 5.4.1+.

**Q: Does SCAN work with Grape API integration?**
A: Yes. Grape extension uses DataSource which uses the updated utils.rb with SCAN support.

**Q: How do I know if SCAN is enabled?**
A: Check logs for `[DEPRECATION] Using KEYS command` warning. If SCAN is enabled, no deprecation warning appears.

**Q: Can I enable SCAN per-environment?**
A: Yes. Use environment variable:
```ruby
config.use_scan = ENV['RP_USE_SCAN'] == 'true'
```

## Additional Resources

- [Redis SCAN Documentation](https://redis.io/docs/latest/commands/scan/)
- [redis-rb scan_each source](https://github.com/redis/redis-rb/blob/master/lib/redis/commands/keys.rb)
- Benchmark script: `test/benchmark/redis_scan_benchmark.rb`

---
**Updated:** 2026-02-06
**Gem Version:** 1.x
