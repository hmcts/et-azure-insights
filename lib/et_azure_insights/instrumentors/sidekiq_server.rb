# frozen_string_literal: true

EtAzureInsights::FeatureDetector.define do
  name :sidekiq_server

  dependency do
    defined?(::Sidekiq) && Sidekiq.server?
  end

  run do
    require 'et_azure_insights/sidekiq/track_server_job'
    require 'et_azure_insights/sidekiq/track_client_job'
    ::Sidekiq.configure_server do |config|
      config.client_middleware do |chain|
        chain.add EtAzureInsights::Sidekiq::TrackClientJob
      end
      config.server_middleware do |chain|
        chain.add EtAzureInsights::Sidekiq::TrackServerJob
      end
    end
  end
end
