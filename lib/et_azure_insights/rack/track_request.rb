# frozen_string_literal: true

require 'application_insights'
module EtAzureInsights
  module Rack
    # Track every request and sends the request data to application insights.
    # Also tracks the request id in the session for use as a 'parent_id'
    # when other data is sent to application insights.
    class TrackRequest < ::ApplicationInsights::Rack::TrackRequest
      def initialize(app, config: EtAzureInsights.config)
        self.config = config
        super(app, config.insights_key)
      end

      private

      attr_accessor :config
    end
  end
end
