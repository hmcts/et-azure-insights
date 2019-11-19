# frozen_string_literal: true

module EtAzureInsights
  module Rack
    # Track every request and sends the request data to application insights.
    # Also tracks the request id in the session for use as a 'parent_id'
    # when other data is sent to application insights.
    class TrackRequest
      def initialize(_app, config: EtAzureInsights.config)
        self.config = config
      end

      private

      attr_accessor :config
    end
  end
end
