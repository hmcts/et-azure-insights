# frozen_string_literal: true

require 'spec_helper'
require 'et_azure_insights/sidekiq/track_client_job'
RSpec.describe EtAzureInsights::Sidekiq::TrackClientJob do
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
  let(:example_worker_class) { 'ExampleWorker' }
  let(:example_queue) { 'default' }
  let(:example_redis_pool) { nil }
  include_context 'insights call collector'

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

    it 'sends dependency data to show the call was made' do
      block_called = false
      middleware.call(example_worker_class, example_job, example_queue, example_redis_pool) do
        block_called = true
      end
      sleep 0.1
      properties_matcher = a_hash_including('jid' => '63ab2d8dc8f4f714b0b5cdec',
                                            'start_time' => instance_of(String))
      base_data_matcher = a_hash_including('name' => 'sidekiq_job_queued',
                                           'properties' => properties_matcher)
      data_matcher = a_hash_including('baseData' => base_data_matcher, 'baseType' => 'EventData')
      expect(insights_call_collector.flatten.map { |call| call.dig('data') }).to include data_matcher
    end
  end
end
