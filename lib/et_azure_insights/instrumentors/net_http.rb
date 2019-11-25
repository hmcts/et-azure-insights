# frozen_string_literal: true

EtAzureInsights::FeatureDetector.define do
  name :net_http

  dependency do
    defined?(Net) && defined?(Net::HTTP)
  end

  run do
    require 'et_azure_insights/adapters/net_http'
    EtAzureInsights::Adapters::NetHttp.setup
  end
end
