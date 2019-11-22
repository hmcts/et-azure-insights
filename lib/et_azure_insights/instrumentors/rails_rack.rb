# frozen_string_literal: true

EtAzureInsights::FeatureDetector.define do
  name :rails_rack

  dependency do
    defined?(::Rails)
  end

  run do
    require 'et_azure_insights/rack/track_request'
    Rails.application.configure do |c|
      c.middleware.use EtAzureInsights::Rack::TrackRequest,
                       config: EtAzureInsights::Config.config
    end
  end
end
