# frozen_string_literal: true

EtAzureInsights::FeatureDetector.define do
  name :sidekiq_client

  dependency do
    defined?(::Sidekiq) && !Sidekiq.server?
  end

  run do
    require 'et_azure_insights/sidekiq/track_client_job'
    ::Sidekiq.configure_client do |config|
      config.client_middleware do |chain|
        chain.add EtAzureInsights::Sidekiq::TrackClientJob
      end
    end
  end
end
