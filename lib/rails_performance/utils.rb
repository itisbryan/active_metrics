# frozen_string_literal: true

module RailsPerformance
  class Utils
    DEFAULT_TIME_OFFSET = 1.minute

    def self.time
      Time.now.utc
    end

    def self.kind_of_now
      time + DEFAULT_TIME_OFFSET
    end

    def self.from_datetimei(datetimei)
      Time.at(datetimei, in: '+00:00')
    end

    # date key in redis store
    def self.cache_key(now = Date.today)
      "date-#{now}"
    end

    # write to current slot
    # time - date -minute
    def self.field_key(now = RailsPerformance::Utils.time)
      now.strftime('%H:%M')
    end

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
      validate_scan_count(count)

      keys = RailsPerformance.redis.scan_each(
        match: query,
        count: count
      ).to_a.sort

      keys
    end

    def self.validate_scan_count(count)
      if count < 1
        raise ArgumentError, "scan_count must be >= 1, got #{count}"
      end

      if count > 10_000
        RailsPerformance.log "[WARNING] scan_count (#{count}) is very high. This may cause long-running SCAN calls. Recommended range: 1-1000.\n"
      end
    end

    def self.determine_scan_count(query)
      return RailsPerformance.scan_count unless RailsPerformance.scan_count_auto_tune

      # Auto-tune based on query type per research recommendations
      case query
      when /datetime|\d{8}/  # Date-scoped query (e.g., datetime|20260204*)
        1000  # Larger COUNT for date ranges
      when /request_id/      # Specific request lookup
        10   # Smaller COUNT for specific lookups
      else                   # Broad queries (controller, action, status, etc.)
        100  # Medium COUNT for general queries
      end
    end

    def self.save_to_redis(key, value, expire = RailsPerformance.duration.to_i)
      # TODO: think here if add return
      # return if value.empty?

      RailsPerformance.log "  [SAVE]    key  --->  #{key}\n"
      RailsPerformance.log "  [SAVE]    value  --->  #{value.to_json}\n\n"
      RailsPerformance.redis.set(key, value.to_json, ex: expire.to_i)
    end

    def self.days(duration = RailsPerformance.duration)
      (duration / 1.day) + 1
    end

    def self.median(array)
      sorted = array.sort
      size = sorted.size
      center = size / 2

      if size.zero?
        nil
      elsif size.even?
        (sorted[center - 1] + sorted[center]) / 2.0
      else
        sorted[center]
      end
    end

    def self.percentile(values, percentile)
      return nil if values.empty?

      sorted = values.sort
      rank = (percentile.to_f / 100) * (sorted.size - 1)

      lower = sorted[rank.floor]
      upper = sorted[rank.ceil]
      lower + (upper - lower) * (rank - rank.floor)
    end
  end
end
