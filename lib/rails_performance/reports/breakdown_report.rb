# frozen_string_literal: true

module RailsPerformance
  module Reports
    class BreakdownReport < BaseReport
      def set_defaults
        @set_defaults ||= :datetimei
      end

      def data
        db.data
          .collect(&:record_hash)
          .sort { |a, b| b[sort] <=> a[sort] }
      end
    end
  end
end
