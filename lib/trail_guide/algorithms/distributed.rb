module TrailGuide
  module Algorithms
    class Distributed < Algorithm
      def choose!(**opts)
        options.sample
      end

      private

      def grouped
        @grouped ||= variants.group_by(&:participants)
      end

      def options
        @options ||= grouped.min_by { |c,g| c }.last
      end
    end
  end
end
