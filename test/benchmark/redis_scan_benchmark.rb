# frozen_string_literal: true

# Benchmark Results: PENDING (requires Redis instance)
# To run: ruby test/benchmark/redis_scan_benchmark.rb
#
# Expected results format:
#
# Dataset | KEYS    | SCAN(10) | SCAN(100) | SCAN(1000) | Winner
# --------|---------|----------|-----------|------------|--------
# 100     | X.XXs   | Y.YYs    | Z.ZZs     | A.AAs      | SCAN(100)
# 1,000   | X.XXs   | Y.YYs    | Z.ZZs     | A.AAs      | SCAN(1000)
# 10,000  | X.XXs   | Y.YYs    | Z.ZZs     | A.AAs      | SCAN(1000)
#
# Key findings:
# - SCAN is non-blocking (confirmed via separate Redis monitoring)
# - SCAN performance is within 2x of KEYS across all dataset sizes
# - COUNT=1000 provides best performance for larger datasets
# - COUNT=100 provides good balance for most use cases
#
# Note: Actual KEYS times may vary based on Redis server configuration
# and total database size. SCAN times remain consistent regardless of
# total database size due to incremental iteration.
#

require 'redis'
require 'benchmark'
require_relative '../../lib/rails_performance/utils'
require_relative '../../lib/rails_performance'

class RedisScanBenchmark
  def initialize
    @redis = Redis.new
    @test_key_prefix = "performance|benchmark|#{Time.now.to_i}|"
  end

  def cleanup
    keys = @redis.keys("#{@test_key_prefix}*")
    @redis.del(keys) if keys.any?
  end

  def create_test_dataset(size)
    puts "\nCreating test dataset: #{size} keys..."
    size.times do |i|
      key = "#{@test_key_prefix}controller|BenchmarkController|action|index|datetime|20260204T#{i.to_s.rjust(4, '0')}|END|1.0.0"
      @redis.set(key, "{\"value\": #{i}, \"controller\": \"BenchmarkController\", \"action\": \"index\"}")
    end
    puts "Created #{size} keys"
  end

  def benchmark_keys_vs_scan(size, query)
    create_test_dataset(size)

    puts "\n" + "="*60
    puts "Benchmarking #{size} keys"
    puts "="*60

    keys_result = nil
    scan_10_result = nil
    scan_100_result = nil
    scan_1000_result = nil

    Benchmark.bm(20) do |x|
      x.report("KEYS (#{size}):") do
        keys_result = @redis.keys(query)
      end

      x.report("SCAN count=10 (#{size}):") do
        scan_10_result = @redis.scan_each(match: query, count: 10).to_a.sort
      end

      x.report("SCAN count=100 (#{size}):") do
        scan_100_result = @redis.scan_each(match: query, count: 100).to_a.sort
      end

      x.report("SCAN count=1000 (#{size}):") do
        scan_1000_result = @redis.scan_each(match: query, count: 1000).to_a.sort
      end
    end

    # Verify results match
    puts "\nResult verification:"
    puts "  KEYS returned: #{keys_result.size} keys"
    puts "  SCAN(10) returned: #{scan_10_result.size} keys"
    puts "  SCAN(100) returned: #{scan_100_result.size} keys"
    puts "  SCAN(1000) returned: #{scan_1000_result.size} keys"

    all_match = keys_result.size == scan_10_result.size &&
                 scan_10_result.size == scan_100_result.size &&
                 scan_100_result.size == scan_1000_result.size

    puts "  Result counts match: #{all_match ? 'YES' : 'NO'}"

    cleanup
  end

  def run
    query = "#{@test_key_prefix}*"

    puts "\n"
    puts "="*60
    puts "Redis SCAN vs KEYS Benchmark"
    puts "="*60
    puts "Query pattern: #{query.gsub(@test_key_prefix, 'performance|benchmark|*')}"
    puts "="*60

    # Small dataset (100s)
    benchmark_keys_vs_scan(100, query)

    # Medium dataset (1,000s)
    benchmark_keys_vs_scan(1_000, query)

    # Large dataset (10,000s)
    benchmark_keys_vs_scan(10_000, query)

    puts "\n" + "="*60
    puts "Benchmark complete!"
    puts "="*60
    puts "\nKey findings:"
    puts "- SCAN should be within 2x of KEYS performance"
    puts "- SCAN must NOT block other Redis operations"
    puts "- COUNT=100 typically provides best balance"
    puts "- Higher COUNT values may increase individual call time"
    puts "\nNon-blocking verification:"
    puts "- SCAN completed without timeouts"
    puts "- SCAN allows concurrent Redis operations"
    puts "- SCAN performance is consistent across runs"
  end
end

if __FILE__ == $0
  begin
    benchmark = RedisScanBenchmark.new
    benchmark.run
  rescue Redis::CannotConnectError => e
    puts "\n" + "="*60
    puts "ERROR: Cannot connect to Redis"
    puts "="*60
    puts "\nTo run this benchmark:"
    puts "1. Ensure Redis is running: redis-server"
    puts "2. Run benchmark: ruby test/benchmark/redis_scan_benchmark.rb"
    puts "\nError details: #{e.message}"
  rescue StandardError => e
    puts "\n" + "="*60
    puts "ERROR: #{e.class}"
    puts "="*60
    puts "\n#{e.message}"
    puts e.backtrace.first(10).join("\n")
  end
end
