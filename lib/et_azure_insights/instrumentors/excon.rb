# frozen_string_literal: true

EtAzureInsights::FeatureDetector.define do
  name :excon

  dependency do
    defined?(::Excon)
  end

  run do
    require 'et_azure_insights/adapters/excon'
    EtAzureInsights::Adapters::Excon.setup
  end
end
