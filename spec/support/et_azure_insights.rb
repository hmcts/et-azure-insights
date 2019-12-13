require 'et_azure_insights'
EtAzureInsights.configure do |config|
  config.enable = true
  config.insights_key = 'fakeazureinsightskey'
  config.insights_role_name = 'fakerolename'
  config.insights_role_instance = 'fakeroleinstance'
  config.buffer_size = 1
  config.send_interval = 0.1
  config.disable_all_features = true
end