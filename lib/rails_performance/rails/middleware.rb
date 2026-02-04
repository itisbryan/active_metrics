# frozen_string_literal: true

module RailsPerformance
  module Rails
    class MiddlewareTraceStorerAndCleanup
      def initialize(app)
        @app = app
      end

      def call(env)
        dup.call!(env)
      end

      def call!(env)
        RailsPerformance.skip = true if /#{RailsPerformance.mount_at}/.match?(env['PATH_INFO'])

        @status, @headers, @response = @app.call(env)

        unless RailsPerformance.skip
          RailsPerformance::Models::TraceRecord.new(
            request_id: CurrentRequest.current.request_id,
            value: CurrentRequest.current.tracings
          ).save
        end

        CurrentRequest.cleanup

        [@status, @headers, @response]
      end
    end

    class Middleware
      def initialize(app)
        @app = app
      end

      def call(env)
        dup.call!(env)
      end

      def call!(env)
        @status, @headers, @response = @app.call(env)

        # t = RailsPerformance::Utils.time
        if !RailsPerformance.skip && !CurrentRequest.current.ignore.include?(:performance) && (data = CurrentRequest.current.data)
          record = RailsPerformance::Models::RequestRecord.new(**data.merge({ request_id: CurrentRequest.current.request_id }))

          # for 500 errors
          record.status ||= @status

          # capture referer from where this page was opened
          record.http_referer = env['HTTP_REFERER'] if record.status == 404

          # we can add custom data, for example Http User-Agent
          # or even devise current_user
          if RailsPerformance.custom_data_proc
            # just to be sure it won't break format how we store in redis
            record.custom_data = RailsPerformance.custom_data_proc.call(env)
          end

          # store for section "recent requests"
          # store request information (regular rails request)
          record.save
        end
        # puts "==> store performance data: #{(RailsPerformance::Utils.time - t).round(3)}ms"

        [@status, @headers, @response]
      end
    end
  end
end
