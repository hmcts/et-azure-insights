# frozen_string_literal: true

require 'spec_helper'
require 'et_azure_insights/adapters/redis'
RSpec.describe EtAzureInsights::Adapters::Redis do
  subject(:adapter) { described_class }
  let(:fake_redis_client) do
    Class.new do
      def call(*)
        :fake_call_response
      end
      def call_pipeline(*)
        :fake_call_pipeline_response
      end
      def connect(*)
        :fake_connect_response
      end
    end
  end

  describe '.setup' do
    it 'modifies the client' do
       adapter.setup(fake_redis_client: fake_redis_client)
      boom!
    end
  end

  describe '#call_pipeline' do
    let(:fake_client) { instance_spy(EtAzureInsights::Client) }
    subject(:adapter_instance) { described_class.new(client: fake_client) }
    let(:fake_pipeline) { instance_spy 'Redis::Pipeline::Multi', commands: fake_pipeline_commands }
    let(:fake_pipeline_commands) { 
      [
        [:multi],
        [:sadd, 'queues', 'events'],
        [:lpush, 'queue:events', '{"some": "data"}']
      ]
    }
    let(:fake_response) { [false, 1] }

    it 'calls the track_dependency method on the telemetry client' do
      subject.call_pipeline(fake_pipeline, 'redis://dummy.server:6379') do
        fake_response
      end
      expect(fake_client).to have_received(:track_dependency)
    end
  end
  
  describe '#call' do
    let(:fake_client) { instance_spy(EtAzureInsights::Client) }
    subject(:adapter_instance) { described_class.new(client: fake_client) }
    let(:fake_command) { [:sadd, 'queues', 'events']  }
    let(:fake_response) { "OK" }

    it 'calls the track_dependency method on the telemetry client' do
      subject.call(fake_command, 'redis://dummy.server:6379') do
        fake_response
      end
      expect(fake_client).to have_received(:track_dependency)
    end
  end

  describe '#connect' do
    let(:fake_client) { instance_spy(EtAzureInsights::Client) }
    subject(:adapter_instance) { described_class.new(client: fake_client) }
    let(:fake_response) { instance_spy('Redis::Client') }

    it 'calls the track_dependency method on the telemetry client' do
      subject.connect('redis://dummy.server:6379') do
        fake_response
      end
      expect(fake_client).to have_received(:track_dependency)
    end
  end
end
