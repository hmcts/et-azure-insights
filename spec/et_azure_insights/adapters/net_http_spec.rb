# frozen_string_literal: true

require 'rails_helper'
require 'et_azure_insights/adapters/net_http'
RSpec.describe EtAzureInsights::Adapters::NetHttp do
  subject(:adapter) { described_class }
  let(:fake_net_http) do
    Class.new do
      def request(*)
        :fake_response
      end
    end
  end

  describe '.setup' do
    it 'configures a middleware object' do
       adapter.setup(net_http: fake_net_http)
      boom!
    end
  end

  describe '#call' do
    let(:fake_client) { instance_spy(EtAzureInsights::Client) }
    subject(:adapter_instance) { described_class.new(client: fake_client) }
    let(:fake_request_attrs) do
      {
        method: 'POST',
        path: '/path'
      }
    end
    let(:fake_request) { instance_spy('Net::HTTP::Post', fake_request_attrs) }
    let(:fake_http_instance) { instance_spy('Net::HTTP', fake_http_instance_attrs) }
    let(:fake_http_instance_attrs) do
      {
        use_ssl?: true,
        address: 'domain.com',
        port: 443
      }
    end
    let(:fake_response) { instance_spy('Net::HTTPOK', fake_response_attrs) }
    let(:fake_response_attrs) do
      {
        code: '200',
        message: 'OK',
        body: '{"some" => "random json"}'
      }
    end

    it 'calls the track_dependency method on the telemetry client' do
      subject.call(fake_request, fake_http_instance) do
        fake_response
      end
      expect(fake_client).to have_received(:track_dependency)
    end
  end
end
