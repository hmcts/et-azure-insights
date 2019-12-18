require 'spec_helper'
require 'et_azure_insights/adapters/sidekiq_server'
require 'sidekiq'
require 'sidekiq/testing'
RSpec.describe EtAzureInsights::Adapters::SidekiqServer do
  include_context 'fake client'
  let(:fake_job_hash) do
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
  let(:fake_worker) { double('FakeWorker') }
  let(:fake_queue) { 'default' }
  subject(:adapter) { described_class.new }

  describe '.setup' do
    context 'with defaults' do
      before do
        allow(Sidekiq).to receive(:server?).and_return true
      end
      after do
        described_class.uninstall
      end

      it 'adds the server middleware to the server config' do
        described_class.setup(sidekiq_config: Sidekiq::Testing)
        expect(Sidekiq::Testing.server_middleware.exists?(described_class)).to be true
      end
    end

    context 'using Sidekiq::Testing' do
      before do
        allow(Sidekiq).to receive(:server?).and_return true
      end
      after do
        described_class.uninstall(sidekiq_config: Sidekiq::Testing)
      end

      it 'adds the server middleware to the server config' do
        described_class.setup(sidekiq_config: Sidekiq::Testing)
        expect(Sidekiq::Testing.server_middleware.exists?(described_class)).to be true
      end

    end
  end

  describe '#call' do
    it 'yields to the caller' do
      expect { |b| adapter.call(fake_worker, fake_job_hash, fake_queue, client: fake_client, &b) }.to yield_control
    end

    it 'returns what the app returns' do
      result = adapter.call(fake_worker, fake_job_hash, fake_queue, client: fake_client) do
        "correct value"
      end

      expect(result).to eq "correct value"
    end

    it 'calls track_request on the telemetry client' do
      adapter.call(fake_worker, fake_job_hash, fake_queue, client: fake_client) { true }

      expect(fake_client).to have_received(:track_request)
    end

    it 'calls track_request with the correct request id' do
      adapter.call(fake_worker, fake_job_hash, fake_queue, client: fake_client) { true }

      expect(fake_client).to have_received(:track_request).with(match(/\A\|[0-9a-f]{32}\.[0-9a-f]{16}\.\z/), anything, anything, anything, anything, anything)
    end

    it 'calls track_request with the correct status' do
      adapter.call(fake_worker, fake_job_hash, fake_queue, client: fake_client) { true }

      expect(fake_client).to have_received(:track_request).with(anything, anything, anything, '200', anything, anything)
    end

    it 'calls track_request with the correct operation id' do
      adapter.call(fake_worker, fake_job_hash, fake_queue, client: fake_client) do
        expect(fake_client_operation).to have_received(:id=).with(match(/\A\|[0-9a-f]{32}\./))
        true
      end
    end

    context 'with job data as if the job had come from a rack request that had been tracked' do
      let(:fake_traceparent) { '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01' }
      let(:fake_job_hash) do
        {
          'class' => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
          'wrapped' => 'EventJob',
          'queue' => 'events',
          'azure_insights_headers' => {
            'traceparent' => fake_traceparent
          },
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

      it 'calls track_dependency with the current operation data set' do
        adapter.call(fake_worker, fake_job_hash, fake_queue, client: fake_client) { true }

        expect(fake_client_operation).to have_received(:id=).with('|4bf92f3577b34da6a3ce929d0e0e4736.').at_least(:once)
        expect(fake_client_operation).to have_received(:parent_id=).with('|4bf92f3577b34da6a3ce929d0e0e4736.00f067aa0ba902b7.')
        expect(fake_client_operation).to have_received(:name=).with('PERFORM /events/JobWrapper/63ab2d8dc8f4f714b0b5cdec').at_least(:once)
        expect(fake_client).to have_received(:track_request)
      end

      it 'calls track_dependency with the request id in the correct format' do
        adapter.call(fake_worker, fake_job_hash, fake_queue, client: fake_client) { true }

        expect(fake_client).to have_received(:track_request).with(match(/\A\|[0-9a-f]{32}\.[0-9a-f]{16}\.\z/), anything, anything, anything, anything, anything)
      end

      it 'calls track_dependency with the request id that does not end with the parent' do
        adapter.call(fake_worker, fake_job_hash, fake_queue, client: fake_client) { true }

        expect(fake_client).to have_received(:track_request).with(satisfy {|s| !s.end_with?('00f067aa0ba902b7.')}, anything, anything, anything, anything, anything)
      end


    end



  end

end
# @TODO - use 3 levels deep to make sure the operation parent id stays the same format (32.16) - integration test found this