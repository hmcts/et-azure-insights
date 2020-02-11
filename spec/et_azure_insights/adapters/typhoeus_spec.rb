# frozen_string_literal: true

require 'spec_helper'
require 'et_azure_insights/adapters/typhoeus'
RSpec.describe EtAzureInsights::Adapters::Typhoeus do
  subject(:adapter) { described_class }
  let(:fake_typhoeus) { spy('Typhoeus') }
  let(:fake_request_options) do
    {
      method: :post,
      body: '{"some": "random json"}',
      headers: {
        'User-Agent' => 'Typhoeus - https://github.com/typhoeus/typhoeus',
        :Accept => 'application/json',
        :'Content-Type' => 'application/json'
      }
    }
  end
  let(:fake_request) { spy('Typhoeus::Request', base_url: 'http://example.com/endpoint', options: fake_request_options) }

  describe '.setup' do
    it 'configures a callback for every request' do
      result = adapter.setup(typhoeus: fake_typhoeus)
      expect(result).to be_a(described_class)
    end

    it 'calls typhoeus before callback with a block which calls the call method on a new instance' do
      # We dont want to test the work done here, just that it appears to be wired correctly
      # The full test of what happens with the request / response cycle is done in the call method
      fake_instance = instance_spy(described_class)
      allow(adapter).to receive(:new).and_return fake_instance
      allow(fake_typhoeus).to receive(:before) do |&block|
        block.call(fake_request)
        expect(fake_instance).to have_received(:call).with(fake_request)
      end
      adapter.setup(typhoeus: fake_typhoeus)
    end

    it 'the typhoeus before callback must return true to ensure the request is ' do
      # We dont want to test the work done here, just that it appears to be wired correctly
      # The full test of what happens with the request / response cycle is done in the call method
      fake_instance = instance_spy(described_class)
      allow(adapter).to receive(:new).and_return fake_instance
      allow(fake_typhoeus).to receive(:before) do |&block|
        result = block.call(fake_request)
        expect(result).to be true
      end
      adapter.setup(typhoeus: fake_typhoeus)
    end
  end

  describe '.uninstall' do
    it 'removes the block added by .setup' do
      fake_instance = instance_spy(described_class)
      allow(adapter).to receive(:new).and_return fake_instance
      blocks_recorded = []
      allow(fake_typhoeus).to receive(:before) do |&block|
        blocks_recorded << block if block
        blocks_recorded
      end
      adapter.setup(typhoeus: fake_typhoeus)
      adapter.uninstall(typhoeus: fake_typhoeus)
      expect(blocks_recorded).to be_empty
    end
  end

  describe '#call' do
    let(:fake_client) { instance_spy(EtAzureInsights::Client) }
    let(:fake_response) { spy('Typhoeus::Response', success?: true, failure?: false, timed_out?: false, status_message: 'OK') }
    subject(:adapter_instance) { described_class.setup(typhoeus: fake_typhoeus) }

    it 'registers with the on_complete callback on the request' do
      subject.call(fake_request, client: fake_client)
      expect(fake_request).to have_received(:on_complete)
    end

    it 'calls the track_dependency method on the telemetry client' do
      on_complete_block = nil
      allow(fake_request).to receive(:on_complete) do |*, &block|
        on_complete_block = block
      end
      subject.call(fake_request, client: fake_client)
      on_complete_block.call(fake_response)

      expect(fake_client).to have_received(:track_dependency)
    end
  end
end
