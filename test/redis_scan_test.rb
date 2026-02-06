# frozen_string_literal: true

require 'test_helper'

class RedisScanTest < ActiveSupport::TestCase
  def setup
    @redis = RailsPerformance.redis
    @test_key_prefix = "performance|test|scan|#{Time.now.to_i}|"
    @redis.keys("#{@test_key_prefix}*").each { |k| @redis.del(k) }
    RailsPerformance.redis = @redis
  end

  def teardown
    @redis.keys("#{@test_key_prefix}*").each { |k| @redis.del(k) }
  end

  def create_test_keys(count, pattern_suffix = "")
    count.times do |i|
      key = "#{@test_key_prefix}#{i}#{pattern_suffix}"
      @redis.set(key, "value_#{i}")
    end
  end

  test "SCAN returns sorted keys" do
    create_test_keys(100)
    query = "#{@test_key_prefix}*"

    RailsPerformance.use_scan = true
    keys, values = RailsPerformance::Utils.fetch_from_redis(query)

    assert_equal 100, keys.size
    assert_equal keys, keys.sort, "SCAN results must be sorted to match KEYS behavior"
  end

  test "KEYS returns unsorted keys" do
    create_test_keys(100)
    query = "#{@test_key_prefix}*"

    RailsPerformance.use_scan = false
    keys, values = RailsPerformance::Utils.fetch_from_redis(query)

    assert_equal 100, keys.size
    # KEYS doesn't guarantee order - SCAN sorts for compatibility
    assert keys.is_a?(Array), "KEYS should return an array"
  end

  test "feature flag toggles between SCAN and KEYS" do
    create_test_keys(50)
    query = "#{@test_key_prefix}*"

    RailsPerformance.use_scan = true
    scan_keys, _ = RailsPerformance::Utils.fetch_from_redis(query)

    RailsPerformance.use_scan = false
    keys_keys, _ = RailsPerformance::Utils.fetch_from_redis(query)

    assert_equal scan_keys.sort, keys_keys.sort, "SCAN and KEYS return same keys"
  end

  test "SCAN with datetime pattern" do
    create_test_keys(50, "|datetime|20260204")
    query = "#{@test_key_prefix}*datetime*20260204*"

    RailsPerformance.use_scan = true
    result = RailsPerformance::Utils.fetch_from_redis(query)

    assert_not_nil result, "Result should not be nil"
    keys, values = result
    assert_operator keys.size, :>, 0, "SCAN should find datetime pattern keys"
    assert_equal keys, keys.sort, "SCAN results must be sorted"
  end

  test "SCAN with controller pattern" do
    create_test_keys(30, "|controller|HomeController|action|index")
    query = "#{@test_key_prefix}*controller|HomeController|action|index*"

    RailsPerformance.use_scan = true
    keys, values = RailsPerformance::Utils.fetch_from_redis(query)

    assert_operator keys.size, :>, 0, "SCAN should find controller pattern keys"
  end

  test "SCAN handles empty results" do
    query = "#{@test_key_prefix}nonexistent*"

    RailsPerformance.use_scan = true
    result = RailsPerformance::Utils.fetch_from_redis(query)

    # fetch_from_redis returns [] when no keys found
    assert_equal [], result, "Empty query should return empty array"
  end

  test "SCAN with large dataset" do
    create_test_keys(1000)
    query = "#{@test_key_prefix}*"

    RailsPerformance.use_scan = true
    keys, values = RailsPerformance::Utils.fetch_from_redis(query)

    assert_equal 1000, keys.size
    assert_equal keys, keys.sort
  end

  test "determine_scan_count uses correct COUNT for datetime queries" do
    RailsPerformance.use_scan = true
    RailsPerformance.scan_count_auto_tune = true

    # Test datetime query (should use 1000)
    count_datetime = RailsPerformance::Utils.determine_scan_count("performance|*|datetime|20260204*|*")
    assert_equal 1000, count_datetime
  end

  test "determine_scan_count uses correct COUNT for specific request lookup" do
    RailsPerformance.use_scan = true
    RailsPerformance.scan_count_auto_tune = true

    # Test specific request query (should use 10)
    count_request = RailsPerformance::Utils.determine_scan_count("performance|*|request_id|xyz|*")
    assert_equal 10, count_request
  end

  test "determine_scan_count uses correct COUNT for broad queries" do
    RailsPerformance.use_scan = true
    RailsPerformance.scan_count_auto_tune = true

    # Test broad query (should use 100)
    count_broad = RailsPerformance::Utils.determine_scan_count("performance|*controller|*")
    assert_equal 100, count_broad
  end

  test "determine_scan_count uses configured scan_count when auto_tune is false" do
    RailsPerformance.use_scan = true
    RailsPerformance.scan_count_auto_tune = false
    RailsPerformance.scan_count = 50

    count = RailsPerformance::Utils.determine_scan_count("performance|*|datetime|20260204*|*")
    assert_equal 50, count
  end

  test "SCAN returns correct values matching keys" do
    create_test_keys(20)
    query = "#{@test_key_prefix}*"

    RailsPerformance.use_scan = true
    keys, values = RailsPerformance::Utils.fetch_from_redis(query)

    assert_equal 20, keys.size
    assert_equal 20, values.size
    assert values.all? { |v| v.is_a?(String) }, "All values should be strings"
  end

  test "SCAN with specific numeric pattern" do
    create_test_keys(10)
    query = "#{@test_key_prefix}*"

    RailsPerformance.use_scan = true
    keys, values = RailsPerformance::Utils.fetch_from_redis(query)

    assert_equal 10, keys.size
    assert keys.all? { |k| k.start_with?(@test_key_prefix) }
  end
end
