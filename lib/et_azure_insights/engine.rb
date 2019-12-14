# frozen_string_literal: true

require 'et_azure_insights/adapters/rack'
module EtAzureInsights
  # This class is to allow the rails application to identify this gem as an engine and call
  # initializers etc..
  class Engine < ::Rails::Engine
    isolate_namespace EtAzureInsights

    config.azure_insights = ::Rails::Application::Configuration::Custom.new
    config.azure_insights.disabled_features = []

    initializer :configure_azure_insights do |app|
      app.config.azure_insights.tap do |ai|
        EtAzureInsights.configure do |c|
          c.enable = ai.enable
          c.insights_key = ai.key
          c.insights_role_name = ai.role_name
          c.insights_role_instance = ai.role_instance
          c.buffer_size = ai.buffer_size
          c.send_interval = ai.send_interval
          c.disabled_features.concat ai.disabled_features
          c.logger = ai.logger unless ai.logger.nil?
        end
      end
    end

    initializer :install_azure_insights_middleware do |app|
      app.configure do |c|
        c.middleware.use EtAzureInsights::Adapters::Rack,
                         config: EtAzureInsights.config
      end
    end
  end
end
