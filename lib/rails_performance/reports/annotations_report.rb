# frozen_string_literal: true

module RailsPerformance
  module Reports
    class AnnotationsReport
      def data
        {
          xaxis: xaxis
        }
      end

      private

      def xaxis
        RailsPerformance::Events::Record.all.map(&:to_annotation)
      end
    end
  end
end
