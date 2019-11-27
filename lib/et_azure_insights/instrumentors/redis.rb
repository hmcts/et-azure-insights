# frozen_string_literal: true

EtAzureInsights::FeatureDetector.define do
  name :redis

  dependency do
    defined?(Redis)
  end

  run do
    require 'et_azure_insights/adapters/redis'
    EtAzureInsights::Adapters::Redis.setup
  end
end
