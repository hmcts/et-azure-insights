# frozen_string_literal: true

Rails.application.configure do |c|
  c.middleware.use EtAzureInsights::Rack::TrackRequest,
                   config: EtAzureInsights::Config.config
end
