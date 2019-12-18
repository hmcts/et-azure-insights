require 'spec_helper'
require 'et_azure_insights/adapters/sidekiq_server'
require 'sidekiq'
RSpec.describe EtAzureInsights::Adapters::SidekiqClient do
  describe '.setup' do
    around do |example|
      example.run
      described_class.uninstall
    end

    it 'adds the client middleware if we are a server' do
      allow(::Sidekiq).to receive(:server?).and_return true
      described_class.setup

      expect(::Sidekiq.client_middleware.exists?(described_class)).to be true
    end

    it 'adds the client middleware if we are a client' do
      allow(::Sidekiq).to receive(:server?).and_return false
      described_class.setup

      expect(::Sidekiq.client_middleware.exists?(described_class)).to be true
    end
  end

  describe '#call' do
    include_context 'fake client'

    let(:example_config) do
      instance_double EtAzureInsights::Config,
                      enable: true,
                      insights_key: 'myinsightskey',
                      insights_role_name: 'myinsightsrolename',
                      insights_role_instance: 'myinsightsroleinstance',
                      buffer_size: 1,
                      send_interval: 0.1,
                      logger: instance_spy(EtAzureInsights::NullLogger)
    end
    subject(:middleware) { described_class.new config: example_config }
    let(:example_worker_class) { 'ExampleWorker' }
    let(:example_queue) { 'default' }
    let(:example_redis_pool) { nil }
    include_context 'insights call collector'

    context 'with span data faking this coming from a rack application 1 level deep' do
      around do |example|
        EtAzureInsights::Correlation::Span.current.open name: 'external operation', id: '0123456789abcdef0123456789abcdef' do |span|
          span.open name: 'GET https://domain.com/path', id: '0123456789abcdef' do |child_span|
            example.run
          end
        end
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

        it 'calls the track_dependency method on the telemetry client' do
          middleware.call(example_worker_class, example_job, example_queue, example_redis_pool, client: fake_client) do
            true
          end
          expect(fake_client).to have_received(:track_dependency)
        end

        it 'calls the track_dependency method with the correct type on the telemetry client' do
          middleware.call(example_worker_class, example_job, example_queue, example_redis_pool, client: fake_client) do
            true
          end
          expect(fake_client).to have_received(:track_dependency).with(anything, anything, anything, anything, hash_including(type: 'Sidekiq (tracked component)'))
        end

        it 'sets the id of the dependency in the correct format' do
          middleware.call(example_worker_class, example_job, example_queue, example_redis_pool, client: fake_client) do
            true
          end

          expect(fake_client).to have_received(:track_dependency).with(match(/\A\|0123456789abcdef0123456789abcdef\.[0-9a-f]{16}\.\z/), anything, anything, anything, anything)
        end

        it 'sets the id of the dependency not ending with the parent' do
          middleware.call(example_worker_class, example_job, example_queue, example_redis_pool, client: fake_client) do
            true
          end

          expect(fake_client).to have_received(:track_dependency).with(satisfy {|s| !s.end_with?('0123456789abcdef.')}, anything, anything, anything, anything)
        end
      end
    end
  end
end