# frozen_string_literal: true

EtAzureInsights::FeatureDetector.define do
  name :active_record

  dependency do
    defined?(::ActiveRecord) && defined?(ActiveSupport) && defined?(ActiveSupport::Notifications)
  end

  run do
    require 'et_azure_insights/adapters/active_record'
    EtAzureInsights::Adapters::ActiveRecord.setup
  end
end
