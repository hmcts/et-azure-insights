# frozen_string_literal: true

require 'rails_helper'
RSpec.describe EtAzureInsights::Sidekiq::TrackServerJob do
  let(:example_config) do
    instance_double EtAzureInsights::Config,
                    enable: true,
                    insights_key: 'myinsightskey',
                    insights_role_name: 'myinsightsrolename',
                    insights_role_instance: 'myinsightsroleinstance',
                    buffer_size: 1,
                    send_interval: 0.1
  end
  subject(:middleware) { described_class.new config: example_config }
  let(:example_worker) { double('Worker') }
  let(:example_queue) { 'default' }
  let(:call_collector) { [] }

  before do
    calls = call_collector
    responder = lambda { |request|
      data = Zlib.gunzip(request.body)
      calls << JSON.parse(data)
      { body: '', status: 200, headers: {} }
    }
    stub_request(:post, 'https://dc.services.visualstudio.com/v2/track')
      .to_return(responder)
  end

  context 'using an active job job' do
    let(:example_job) do
      {
        'class' => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
        'wrapped' => 'EventJob',
        'queue' => 'events',
        'args' => [
          {
            'job_class' => 'EventJob',
            'job_id' => '57cd9ebe-b735-4183-b9cf-4a603b3deea9',
            'provider_job_id' => nil,
            'queue_name' => 'events',
            'priority' => nil,
            'arguments' => [
              'PrepareClaimHandler',
              {
                '_aj_globalid' => 'gid://et-api/Claim/238'
              }
            ],
            'executions' => 0,
            'exception_executions' => {},
            'locale' => 'en',
            'timezone' => 'UTC',
            'enqueued_at' => '2019-11-19T15:54:20Z'
          }
        ],
        'retry' => true,
        'jid' => '63ab2d8dc8f4f714b0b5cdec',
        'created_at' => 1_574_178_860.215001
      }
    end

    it 'sends request data to show the call was made' do
      middleware.call(example_worker, example_job, example_queue) {}
      sleep 0.01

      base_data_matcher = a_hash_including 'responseCode' => 200,
                                           'success' => true
      data_matcher = a_hash_including('baseData' => base_data_matcher, 'baseType' => 'RequestData')
      expect(call_collector.flatten.map { |call| call.dig('data') }).to include data_matcher
    end

    it 'sends request data with the correct cloud role and instance' do
      middleware.call(example_worker, example_job, example_queue) {}
      sleep 0.1
      data_matcher = a_hash_including 'ai.cloud.role' => example_config.insights_role_name,
                                      'ai.cloud.roleInstance' => example_config.insights_role_instance
      expect(call_collector.flatten.map { |call| call.dig('tags') }).to include data_matcher
    end

    it 'yields with the job id as the request id in the tracker' do
      stack_bottom_during = nil
      middleware.call(example_worker, example_job, example_queue) do
        stack_bottom_during = EtAzureInsights::RequestStack.last
      end
      sleep 0.01
      expect([stack_bottom_during, EtAzureInsights::RequestStack.last]).to eq ["sidekiq-#{example_job['jid']}", nil]
    end
  end
end
