require 'spec_helper'
require 'et_azure_insights'
require 'et_azure_insights/request_adapter/rack'
require 'rack/mock'
RSpec.describe EtAzureInsights::RequestAdapter::SidekiqJob do
  subject(:adapter) { described_class }

  describe '.from_job_hash' do
    let(:fake_job_hash) do
      {
        'class' => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
        'wrapped' => 'EventJob',
        'queue' => 'my_queue',
        'azure_insights_headers' => {
          'TEST_HEADER' => 'test header value'
        },
        'args' => [
          {
            'job_class' => 'EventJob',
            'job_id' => '57cd9ebe-b735-4183-b9cf-4a603b3deea9',
            'provider_job_id' => nil,
            'queue_name' => 'my_queue',
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

    it 'builds an instance' do
      result = described_class.from_job_hash(fake_job_hash)

      expect(result).to be_a(described_class)
    end

    it 'has the correct url' do
      result = described_class.from_job_hash(fake_job_hash)

      expect(result.url).to eql 'sidekiq://my_queue/JobWrapper/63ab2d8dc8f4f714b0b5cdec'
    end

    it 'has the correct name' do
      result = described_class.from_job_hash(fake_job_hash)

      expect(result.name).to eql 'PERFORM /my_queue/JobWrapper/63ab2d8dc8f4f714b0b5cdec'
    end

    it 'has the correct request_method' do
      result = described_class.from_job_hash(fake_job_hash)

      expect(result.request_method).to be :perform

    end

    it 'has the header' do
      result = described_class.from_job_hash(fake_job_hash)

      expect(result.fetch_header('TEST_HEADER')).to eql 'test header value'
    end
  end

  describe '#get_header' do
    let(:fake_job_hash) do
      {
        'class' => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
        'wrapped' => 'EventJob',
        'queue' => 'events',
        'azure_insights_headers' => {
          'TEST_HEADER' => 'test header value'
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
    subject(:adapter) { described_class.from_job_hash(fake_job_hash) }

    it 'is nil if the header does not exist' do
      expect(subject.get_header('DOESNT_EXIST')).to be_nil
    end

    it 'is the value given' do
      expect(subject.get_header('TEST_HEADER')).to eql 'test header value'
    end
  end

  describe '#fetch_header' do
    let(:fake_job_hash) do
      {
        'class' => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
        'wrapped' => 'EventJob',
        'queue' => 'events',
        'azure_insights_headers' => {
          'TEST_HEADER' => 'test header value'
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
    subject(:adapter) { described_class.from_job_hash(fake_job_hash) }

    it 'is raises an exception if the header does not exist' do
      expect { subject.fetch_header('DOESNT_EXIST') }.to raise_error(KeyError)
    end

    it 'is the value given' do
      expect(subject.fetch_header('TEST_HEADER')).to eql 'test header value'
    end
  end

  describe '#has_header?' do
    let(:fake_job_hash) do
      {
        'class' => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
        'wrapped' => 'EventJob',
        'queue' => 'my_queue',
        'azure_insights_headers' => {
          'TEST_HEADER' => 'test header value'
        },
        'args' => [
          {
            'job_class' => 'EventJob',
            'job_id' => '57cd9ebe-b735-4183-b9cf-4a603b3deea9',
            'provider_job_id' => nil,
            'queue_name' => 'my_queue',
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
    subject(:adapter) { described_class.from_job_hash(fake_job_hash) }

    it 'is false if the header does not exist' do
      expect(subject.has_header?('DOESNT_EXIST')).to be false
    end

    it 'is true if the header does exist' do
      expect(subject.has_header?('TEST_HEADER')).to be true
    end
  end

  describe '#trace_id' do
    let(:fake_trace_parent_parser) { class_spy('EtAzureInsights::TraceParent', parse: example_trace_parent) }
    let(:example_trace_parent) { instance_spy('EtAzureInsights::TraceParent', version: '00', trace_id: 'sometraceid', span_id: 'some_span_id', trace_flag: '01') }

    context 'with no traceparent header' do
      let(:fake_job_hash) do
        {
          'class' => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
          'wrapped' => 'EventJob',
          'queue' => 'my_queue',
          'args' => [
            {
              'job_class' => 'EventJob',
              'job_id' => '57cd9ebe-b735-4183-b9cf-4a603b3deea9',
              'provider_job_id' => nil,
              'queue_name' => 'my_queue',
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
      subject(:adapter) { described_class.from_job_hash(fake_job_hash, trace_parent: fake_trace_parent_parser) }

      it 'should be nil' do
        expect(subject.trace_id).to be_nil
      end
    end

    context 'with a traceparent header' do
      let(:fake_job_hash) do
        {
          'class' => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
          'wrapped' => 'EventJob',
          'queue' => 'events',
          'azure_insights_headers' => {
            'traceparent' => 'traceparentheadervalue'
          },
          'args' => [
            {
              'job_class' => 'EventJob',
              'job_id' => '57cd9ebe-b735-4183-b9cf-4a603b3deea9',
              'provider_job_id' => nil,
              'queue_name' => 'my_queue',
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

      subject(:adapter) { described_class.from_job_hash(fake_job_hash, trace_parent: fake_trace_parent_parser) }

      it 'requests the value from the traceparent parser' do
        subject.trace_id

        expect(fake_trace_parent_parser).to have_received(:parse).with('traceparentheadervalue')
      end

      it 'returns the correct trace_id from the traceparent parser results' do
        expect(subject.trace_id).to eql 'sometraceid'
      end

      it 'returns nil of the traceparent parser returned nil' do
        allow(fake_trace_parent_parser).to receive(:parse).and_return nil

        expect(subject.trace_id).to be_nil
      end
    end

  end

  describe '#span_id' do
    let(:fake_trace_parent_parser) { class_spy('EtAzureInsights::TraceParent', parse: example_trace_parent) }
    let(:example_trace_parent) { instance_spy('EtAzureInsights::TraceParent', version: '00', trace_id: 'sometraceid', span_id: 'some_span_id', trace_flag: '01') }

    context 'with no traceparent header' do
      let(:fake_job_hash) do
        {
          'class' => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
          'wrapped' => 'EventJob',
          'queue' => 'my_queue',
          'args' => [
            {
              'job_class' => 'EventJob',
              'job_id' => '57cd9ebe-b735-4183-b9cf-4a603b3deea9',
              'provider_job_id' => nil,
              'queue_name' => 'my_queue',
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
      subject(:adapter) { described_class.from_job_hash(fake_job_hash, trace_parent: fake_trace_parent_parser) }

      it 'should be nil' do
        expect(subject.span_id).to be_nil
      end
    end

    context 'with a traceparent header' do
      let(:fake_job_hash) do
        {
          'class' => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
          'wrapped' => 'EventJob',
          'queue' => 'my_queue',
          'azure_insights_headers' => {
            'traceparent' => 'traceparentheadervalue'
          },
          'args' => [
            {
              'job_class' => 'EventJob',
              'job_id' => '57cd9ebe-b735-4183-b9cf-4a603b3deea9',
              'provider_job_id' => nil,
              'queue_name' => 'my_queue',
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
      subject(:adapter) { described_class.from_job_hash(fake_job_hash, trace_parent: fake_trace_parent_parser) }

      it 'requests the value from the traceparent parser' do
        subject.span_id

        expect(fake_trace_parent_parser).to have_received(:parse).with('traceparentheadervalue')
      end

      it 'returns the correct span_id from the traceparent parser results' do
        expect(subject.span_id).to eql 'some_span_id'
      end

      it 'returns nil of the traceparent parser returned nil' do
        allow(fake_trace_parent_parser).to receive(:parse).and_return nil

        expect(subject.span_id).to be_nil
      end
    end
  end

  describe '#trace_info?' do
    let(:fake_trace_parent_parser) { class_spy('EtAzureInsights::TraceParent', parse: example_trace_parent) }
    let(:example_trace_parent) { instance_spy('EtAzureInsights::TraceParent', version: '00', trace_id: 'sometraceid', span_id: 'some_span_id', trace_flag: '01') }

    context 'with no traceparent header' do
      let(:fake_job_hash) do
        {
          'class' => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
          'wrapped' => 'EventJob',
          'queue' => 'my_queue',
          'args' => [
            {
              'job_class' => 'EventJob',
              'job_id' => '57cd9ebe-b735-4183-b9cf-4a603b3deea9',
              'provider_job_id' => nil,
              'queue_name' => 'my_queue',
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
      subject(:adapter) { described_class.from_job_hash(fake_job_hash, trace_parent: fake_trace_parent_parser) }

      it 'should be false' do
        expect(subject.trace_info?).to be false
      end
    end

    context 'with a traceparent header' do
      let(:fake_job_hash) do
        {
          'class' => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
          'wrapped' => 'EventJob',
          'queue' => 'my_queue',
          'azure_insights_headers' => {
            'traceparent' => 'traceparentheadervalue'
          },
          'args' => [
            {
              'job_class' => 'EventJob',
              'job_id' => '57cd9ebe-b735-4183-b9cf-4a603b3deea9',
              'provider_job_id' => nil,
              'queue_name' => 'my_queue',
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
      subject(:adapter) { described_class.from_job_hash(fake_job_hash, trace_parent: fake_trace_parent_parser) }

      it 'should be true if parsed ok' do
        expect(subject.trace_info?).to be true
      end

      it 'returns false of the traceparent parser returned nil' do
        allow(fake_trace_parent_parser).to receive(:parse).and_return nil

        expect(subject.trace_info?).to be false
      end
    end
  end

  # @TODO test request_id
end