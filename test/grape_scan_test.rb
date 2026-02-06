# frozen_string_literal: true

require 'test_helper'

class GrapeScanTest < ActiveSupport::TestCase
  def setup
    reset_redis  # Clear all keys from test database
    @redis = RailsPerformance.redis
    RailsPerformance.use_scan = false  # Start with KEYS
  end

  def teardown
    reset_redis  # Clean up after each test
  end

  def create_grape_keys(count, datetime: nil, status: '200', format: 'json', method: 'GET', path: '/api/test')
    datetime ||= RailsPerformance::Utils.time
    count.times do |i|
      dt = datetime + i.seconds
      record = RailsPerformance::Models::GrapeRecord.new(
        datetime: dt.strftime(RailsPerformance::FORMAT),
        datetimei: dt.to_i,
        format: format,
        path: path,
        status: status,
        method: method,
        request_id: SecureRandom.hex(16),
        endpoint_render_grape: rand(10),
        endpoint_run_grape: rand(10),
        format_response_grape: rand(10)
      )
      # Save the record using the standard GrapeRecord.save method
      # This creates the key in the correct format
      record.instance_variable_set(:@datetime, dt.strftime(RailsPerformance::FORMAT))
      record.instance_variable_set(:@datetimei, dt.to_i)
      key = "grape|datetime|#{dt.strftime(RailsPerformance::FORMAT)}|datetimei|#{dt.to_i}|format|#{format}|path|#{path}|status|#{status}|method|#{method}|request_id|#{record.request_id}|END|#{RailsPerformance::SCHEMA}"
      value = { 'endpoint_render.grape' => record.endpoint_render_grape, 'endpoint_run.grape' => record.endpoint_run_grape, 'format_response.grape' => record.format_response_grape }
      @redis.set(key, value.to_json)
    end
  end

  test "Grape query pattern with KEYS returns results" do
    create_grape_keys(50)
    query = "grape|*datetime|#{RailsPerformance::Utils.time.strftime('%Y%m%d')}*|END|#{RailsPerformance::SCHEMA}"

    RailsPerformance.use_scan = false
    keys, values = RailsPerformance::Utils.fetch_from_redis(query)

    assert_equal 50, keys.size, "KEYS should return all 50 keys"
    assert keys.is_a?(Array), "KEYS should return an array"
  end

  test "Grape query pattern with SCAN returns sorted results" do
    create_grape_keys(50)
    query = "grape|*datetime|#{RailsPerformance::Utils.time.strftime('%Y%m%d')}*|END|#{RailsPerformance::SCHEMA}"

    RailsPerformance.use_scan = true
    keys_scan, values_scan = RailsPerformance::Utils.fetch_from_redis(query)

    assert_equal 50, keys_scan.size, "SCAN should return all 50 keys"
    assert_equal keys_scan, keys_scan.sort, "SCAN results must be sorted to match KEYS behavior"
  end

  test "SCAN and KEYS return same keys for Grape queries" do
    create_grape_keys(100)
    query = "grape|*datetime|#{RailsPerformance::Utils.time.strftime('%Y%m%d')}*|END|#{RailsPerformance::SCHEMA}"

    RailsPerformance.use_scan = true
    keys_scan, values_scan = RailsPerformance::Utils.fetch_from_redis(query)

    RailsPerformance.use_scan = false
    keys_keys, values_keys = RailsPerformance::Utils.fetch_from_redis(query)

    assert_equal keys_scan.sort, keys_keys.sort, "SCAN and KEYS should return same keys"
    assert_equal 100, keys_scan.size, "All keys should be found"
  end

  test "Grape status filter with SCAN" do
    create_grape_keys(30, status: '200')
    create_grape_keys(10, status: '500', path: '/api/error')

    RailsPerformance.use_scan = true
    ds = RailsPerformance::DataSource.new(type: :grape, q: { on: Date.today, status: '200' })
    result = ds.add_to

    assert_equal 30, result.data.size, "Should find 30 keys with status 200"
    result.data.each do |record|
      assert_equal '200', record.status, "All records should have status 200"
    end
  end

  test "Grape datetime filter with SCAN" do
    target_date = Date.today
    create_grape_keys(50, datetime: target_date.to_time)

    RailsPerformance.use_scan = true
    ds = RailsPerformance::DataSource.new(type: :grape, q: { on: target_date })
    result = ds.add_to

    assert_equal 50, result.data.size, "Should find 50 keys for target date"
  end

  test "Grape DataSource with SCAN vs KEYS parity" do
    create_grape_keys(100)

    RailsPerformance.use_scan = true
    ds_scan = RailsPerformance::DataSource.new(type: :grape, q: { on: Date.today })
    result_scan = ds_scan.add_to

    RailsPerformance.use_scan = false
    ds_keys = RailsPerformance::DataSource.new(type: :grape, q: { on: Date.today })
    result_keys = ds_keys.add_to

    assert_equal result_keys.data.size, result_scan.data.size, "SCAN and KEYS should return same count"
    assert_equal 100, result_scan.data.size, "All records should be found"
  end

  test "Grape extension does not use direct Redis KEYS calls" do
    grape_ext_code = File.read('lib/rails_performance/gems/grape_ext.rb')

    refute_match(/redis\.keys\(/i, grape_ext_code, "Grape extension should not call redis.keys directly")
    assert_match(/GrapeRecord/, grape_ext_code, "Grape extension should use GrapeRecord")
  end

  test "Grape key pattern matches SCAN expectations" do
    # Grape key format: grape|datetime|YYYYMMDDTHHMMSS|datetimei|...|status|...|END|SCHEMA
    datetime = RailsPerformance::Utils.time
    create_grape_keys(1, datetime: datetime, status: '200')

    # Query with date wildcard
    query = "grape|*datetime|#{datetime.strftime('%Y%m%d')}*|END|#{RailsPerformance::SCHEMA}"

    RailsPerformance.use_scan = true
    keys, values = RailsPerformance::Utils.fetch_from_redis(query)

    assert_equal 1, keys.size, "Should find the Grape key with date wildcard"
    assert_match(/datetime\|#{datetime.strftime('%Y%m%d')}/, keys.first, "Key should contain date")
  end

  test "Grape empty query returns empty array" do
    query = "grape|nonexistent*"

    RailsPerformance.use_scan = true
    result = RailsPerformance::Utils.fetch_from_redis(query)

    # fetch_from_redis returns [] when no keys found (existing behavior)
    assert_equal [], result, "Empty query should return empty array"
  end
end
