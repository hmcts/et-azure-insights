# frozen_string_literal: true

require 'spec_helper'
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
    include_context 'fake client'
    subject(:adapter_instance) { described_class.new }
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
        use_ssl?: false,
        address: 'domain.com',
        port: 81
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

    context 'with span data faking this coming from a rack application 1 level deep' do
      around do |example|
        EtAzureInsights::Correlation::Span.current.open name: 'external operation', id: '0123456789abcdef0123456789abcdef' do |span|
          span.open name: 'GET https://domain.com/path', id: '0123456789abcdef' do |child_span|
            example.run
          end
        end
      end

      it 'calls the track_dependency method on the telemetry client' do
        subject.call(fake_request, fake_http_instance, client: fake_client) do
          fake_response
        end
        expect(fake_client).to have_received(:track_dependency)
      end

      it 'calls the track_dependency method with the correct type on the telemetry client' do
        subject.call(fake_request, fake_http_instance, client: fake_client) do
          fake_response
        end
        expect(fake_client).to have_received(:track_dependency).with(anything, anything, anything, anything, hash_including(type: 'Http (tracked component)'))
      end

      it 'sets the target of the dependency correctly' do
        subject.call(fake_request, fake_http_instance, client: fake_client) do
          fake_response
        end

        expect(fake_client).to have_received(:track_dependency).with(anything, anything, anything, anything, hash_including(target: 'domain.com:81'))
      end

      # @TODO it should set the target differently if the Request-Context header is set with the appId different to ours
      # @TODO it should not set the target differently if the Request-Context header is set with the appId the same as ours
      #

      it 'sets the id of the dependency in the correct format' do
        subject.call(fake_request, fake_http_instance, client: fake_client) do
          fake_response
        end

        expect(fake_client).to have_received(:track_dependency).with(match(/\A\|0123456789abcdef0123456789abcdef\.[0-9a-f]{16}\.\z/), anything, anything, anything, anything)
      end

      it 'sets the id of the dependency not ending with the parent' do
        subject.call(fake_request, fake_http_instance, client: fake_client) do
          fake_response
        end

        expect(fake_client).to have_received(:track_dependency).with(satisfy {|s| !s.end_with?('0123456789abcdef.')}, anything, anything, anything, anything)
      end

      # @TODO Does the id of the depencency have to contain the parent id ?  I dont think so - might just be for convenience
    end
  end
end
