# frozen_string_literal: true

require 'rails_helper'
require 'et_azure_insights'
RSpec.describe 'EtAzureInsights rails integration' do
  it 'modifies the application to include the middleware' do
    app_config = Dummy::Application.config
    expect(app_config.middleware).to include EtAzureInsights::Rack::TrackRequest
  end
end
