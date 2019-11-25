# frozen_string_literal: true

require 'rails_helper'
require 'et_azure_insights/adapters/excon'
RSpec.describe EtAzureInsights::Adapters::Excon do
  subject(:adapter) { described_class }
  let(:fake_excon_defaults) do
    {
      middlewares: []
    }
  end
  let(:fake_excon) { spy('Excon', defaults: fake_excon_defaults) }
  let(:fake_excon_stack) { spy('Excon::Middleware::Base') }
  let(:fake_response_datum) do
    {
      headers: {
        'User-Agent' => 'fog-core/2.1.2',
        'Host' => 's3.et.127.0.0.1.nip.io'
      },
      idempotant: true,
      instrumentor_name: 'excon',
      mock: false,
      host: 's3.et.127.0.0.1.nip.io',
      hostname: 's3.et.127.0.0.1.nip.io',
      path: '/et1bucket/uploads/claim/pdf/7Z4T-K3CW/et1_humberto_roberts.pdf',
      port: 3100,
      query: nil,
      scheme: 'http',
      method: 'HEAD',
      response: {
        body: '{"some": "random json"}',
        cookies: [],
        host: 's3.et.127.0.0.1.nip.io',
        headers: {
          'Content-Type' => 'application/json',
          'X-Amz-Request-Id' => '15D986961946973C'
        },
        path: '/et1bucket/uploads/claim/pdf/7Z4T-K3CW/et1_humberto_roberts.pdf',
        port: 3100,
        status: 200,
        status_line: 'HTTP/1.1 200 OK',
        reason_phrase: 'OK'
      }
    }
  end

  describe '.setup' do
    it 'configures a middleware object' do
       adapter.setup(excon: fake_excon)
      expect(fake_excon.defaults[:middlewares]).to include described_class
    end
  end

  describe '#response_call' do
    let(:fake_client) { instance_spy(EtAzureInsights::Client) }
    subject(:adapter_instance) { described_class.new(fake_excon_stack, client: fake_client) }

    it 'calls the track_dependency method on the telemetry client' do
      subject.response_call(fake_response_datum)
      expect(fake_client).to have_received(:track_dependency)
    end
  end
end
