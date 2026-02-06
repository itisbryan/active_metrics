# Phase 1: Redis SCAN Migration - Context

**Gathered:** 2026-02-04
**Status:** Ready for planning

## Phase Boundary

Replace blocking Redis KEYS command with non-blocking SCAN iteration throughout the codebase. This is an infrastructure change to prevent Redis server blocking during key iteration — a production safety improvement. No new monitoring features are added; existing functionality is preserved.

## Implementation Decisions

### Feature flag strategy
- Shield new SCAN code behind flag; KEYS runs by default when flag off
- Permanent long-term flag (safety valve, never removed)
- Flag configured via gem configuration: `RailsPerformance.use_scan = true/false`
- Add deprecation warning when KEYS path is used, guiding users to SCAN

### SCAN COUNT tuning
- Default COUNT value: 10 (Redis default)
- Auto-tune COUNT per query type (researcher to determine optimal values)
- Configuration option named `scan_count`
- Warn if COUNT value is extreme (<1 or >10000)

### Backwards compatibility
- Strict breaking change bar: any difference in behavior is breaking
- Must preserve key order: sort SCAN results to match KEYS order
- Deprecate KEYS path with warning, keep available indefinitely via flag
- Minor/patch version change (1.x), not major version bump

### Performance validation
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

## Specific Ideas

No specific product references — this is pure infrastructure migration following Redis and Ruby community best practices.

## Deferred Ideas

None — discussion stayed within phase scope.

---

*Phase: 01-redis-scan-migration*
*Context gathered: 2026-02-04*
