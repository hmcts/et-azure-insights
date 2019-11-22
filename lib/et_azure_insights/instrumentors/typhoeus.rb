# frozen_string_literal: true

EtAzureInsights::FeatureDetector.define do
  name :typhoeus

  dependency do
    defined?(::Typhoeus)
  end

  run do
    require 'et_azure_insights/adapters/typhoeus'
    EtAzureInsights::Adapters::Typhoeus.setup
  end
end
