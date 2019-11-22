# frozen_string_literal: true

module EtAzureInsights
  # This class is to allow the rails application to identify this gem as an engine and call
  # initializers etc..
  class Engine < ::Rails::Engine
    isolate_namespace EtAzureInsights

    config.azure_insights = ::Rails::Application::Configuration::Custom.new

    initializer :configure_azure_insights do |app|
      app.config.azure_insights.tap do |ai|
        EtAzureInsights.configure do |c|
          c.enable = ai.enable
          c.insights_key = ai.key
          c.insights_role_name = ai.role_name
          c.insights_role_instance = ai.role_instance
          c.buffer_size = ai.buffer_size
          c.send_interval = ai.send_interval
        end
      end
    end

    initializer :install_azure_insights_features do
      FeatureDetector.install_all!
    end
  end
end
