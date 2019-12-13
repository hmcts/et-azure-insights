RSpec.shared_context 'fake client' do
  let(:fake_client) { instance_spy(EtAzureInsights::Client, context: fake_client_context) }
  let(:fake_client_context) do
    instance_spy 'ApplicationInsights::Channel::TelemetryContext',
                 operation: fake_client_operation,
                 application: fake_client_application,
                 cloud: fake_client_cloud,
                 device: fake_client_device,
                 user: fake_client_user,
                 session: fake_client_session,
                 location: fake_client_location
  end
  let(:fake_client_operation) { instance_spy('ApplicationInsights::Channel::Contracts::Operation') }
  let(:fake_client_application)  { instance_spy('ApplicationInsights::Channel::Contracts::Application') }
  let(:fake_client_cloud) { instance_spy('ApplicationInsights::Channel::Contracts::Cloud') }
  let(:fake_client_device) { instance_spy('ApplicationInsights::Channel::Contracts::Device') }
  let(:fake_client_user) { instance_spy('ApplicationInsights::Channel::Contracts::User') }
  let(:fake_client_session) { instance_spy('ApplicationInsights::Channel::Contracts::Session') }
  let(:fake_client_location) { instance_spy('ApplicationInsights::Channel::Contracts::Location') }

end