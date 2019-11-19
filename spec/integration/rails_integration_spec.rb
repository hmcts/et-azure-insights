# frozen_string_literal: true

require 'rails_helper'
require 'et_azure_insights'
RSpec.describe 'EtAzureInsights rails integration' do
  it 'modifies the application to include the middleware' do
    app_config = Dummy::Application.config
    expect(app_config.middleware).to include EtAzureInsights::Rack::TrackRequest
  end

  it 'loads the config from rails if specified' do
    app_config = Dummy::Application.config
    insights_config = app_config.azure_insights
    expect(EtAzureInsights.config).to have_attributes insights_key: insights_config.key,
                                                      enable: insights_config.enable,
                                                      insights_role_name: insights_config.role_name,
                                                      insights_role_instance: insights_config.role_instance
  end
end
