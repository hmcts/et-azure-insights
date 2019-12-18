require 'sidekiq'
require 'et_azure_insights/adapters/sidekiq_server'
require 'et_azure_insights/adapters/sidekiq_client'
require 'sidekiq/testing'
# A shared context to configure fake sidekiq exactly how the real thing is setup, with the correct middleware
# it was decided not to use real sidekiq processes whicih would have been more realistic, but with too much overhead i.e. redis etc..
RSpec.shared_context 'fake sidekiq environment' do
  around do |example|
    EtAzureInsights::Adapters::SidekiqClient.setup
    EtAzureInsights::Adapters::SidekiqServer.setup(sidekiq_config: Sidekiq::Testing)
    Sidekiq::Testing.fake! do
      Sidekiq::Worker.clear_all
      example.run
    end
    EtAzureInsights::Adapters::SidekiqClient.uninstall
    EtAzureInsights::Adapters::SidekiqServer.uninstall(sidekiq_config: Sidekiq::Testing)

  end
end