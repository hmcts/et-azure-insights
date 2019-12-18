# frozen_string_literal: true

EtAzureInsights::FeatureDetector.define do
  name :sidekiq_client

  dependency do
    defined?(::Sidekiq) && !Sidekiq.server?
  end

  run do
    require 'et_azure_insights/adapters/sidekiq_client'
    EtAzureInsights::Adapters::SidekiqClient.setup
  end
end
