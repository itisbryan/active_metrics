# frozen_string_literal: true

module RailsPerformance
  module Gems
    # Grape API extension for collecting performance metrics
    #
    # SCAN Compatibility:
    # This extension only collects metrics (writes to Redis via GrapeRecord.save)
    # It does not query Redis directly - reading uses DataSource which calls Utils.fetch_from_redis
    #
    # Write path: GrapeExt -> GrapeRecord.save -> Utils.save_to_redis -> Redis SET
    # Read path: DataSource(type: :grape) -> Utils.fetch_from_redis -> SCAN (when use_scan = true)
    #
    # No changes needed for SCAN compatibility - writes use direct SET, reads use updated utils.rb
    class GrapeExt
      def self.init
        ActiveSupport::Notifications.subscribe(/grape/) do |name, start, finish, _id, payload|
          # TODO: change to set
          CurrentRequest.current.ignore.add(:performance)

          now = RailsPerformance::Utils.time
          CurrentRequest.current.data ||= {}
          CurrentRequest.current.record ||= RailsPerformance::Models::GrapeRecord.new(request_id: CurrentRequest.current.request_id)
          CurrentRequest.current.record.datetimei ||= now.to_i
          CurrentRequest.current.record.datetime ||= now.strftime(RailsPerformance::FORMAT)

          if ['endpoint_render.grape', 'endpoint_run.grape', 'format_response.grape'].include?(name)
            CurrentRequest.current.record.send("#{name.tr('.', '_')}=", (finish - start) * 1000)
          end

          if payload[:env]
            CurrentRequest.current.record.status = payload[:env]['api.endpoint'].status
            CurrentRequest.current.record.format = payload[:env]['api.format']
            CurrentRequest.current.record.method = payload[:env]['REQUEST_METHOD']
            CurrentRequest.current.record.path = payload[:env]['PATH_INFO']
          end

          expects_no_content = Rack::Utils::STATUS_WITH_NO_ENTITY_BODY.include?(CurrentRequest.current.record.status)
          if name == 'format_response.grape' ||
             (name == 'endpoint_run.grape' && (payload[:endpoint]&.body.nil? || expects_no_content))
            CurrentRequest.current.record.save
            CurrentRequest.cleanup
          end
        end
      end
    end
  end
end
