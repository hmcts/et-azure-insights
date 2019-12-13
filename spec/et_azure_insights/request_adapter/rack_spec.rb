require 'spec_helper'
require 'et_azure_insights'
require 'et_azure_insights/request_adapter/rack'
require 'rack/mock'
RSpec.describe EtAzureInsights::RequestAdapter::Rack do
  subject(:adapter) { described_class }

  describe '.from_env' do
    let(:fake_request_env) { ::Rack::MockRequest.env_for('http://www.dummy.com/endpoint?test=1', method: :get, 'TEST_HEADER' => 'test header value') }

    it 'builds an instance' do
      result = described_class.from_env(fake_request_env)

      expect(result).to be_a(described_class)
    end

    it 'has the correct url' do
      result = described_class.from_env(fake_request_env)

      expect(result.url).to eql 'http://www.dummy.com/endpoint?test=1'
    end

    it 'has the correct name' do
      result = described_class.from_env(fake_request_env)

      expect(result.name).to eql 'GET /endpoint'
    end

    it 'has the correct request_method' do
      result = described_class.from_env(fake_request_env)

      expect(result.request_method).to be :get

    end

    it 'has the header' do
      result = described_class.from_env(fake_request_env)

      expect(result.fetch_header('TEST_HEADER')).to eql 'test header value'
    end
  end

  describe '#get_header' do
    let(:fake_request_env) { ::Rack::MockRequest.env_for('http://www.dummy.com/endpoint?test=1', method: :get, 'TEST_HEADER' => 'test header value') }
    subject(:adapter) { described_class.from_env(fake_request_env) }

    it 'is nil if the header does not exist' do
      expect(subject.get_header('DOESNT_EXIST')).to be_nil
    end

    it 'is the value given' do
      expect(subject.get_header('TEST_HEADER')).to eql 'test header value'
    end
  end

  describe '#fetch_header' do
    let(:fake_request_env) { ::Rack::MockRequest.env_for('http://www.dummy.com/endpoint?test=1', method: :get, 'TEST_HEADER' => 'test header value') }
    subject(:adapter) { described_class.from_env(fake_request_env) }

    it 'is raises an exception if the header does not exist' do
      expect { subject.fetch_header('DOESNT_EXIST') }.to raise_error(KeyError)
    end

    it 'is the value given' do
      expect(subject.fetch_header('TEST_HEADER')).to eql 'test header value'
    end
  end

  describe '#has_header?' do
    let(:fake_request_env) { ::Rack::MockRequest.env_for('http://www.dummy.com/endpoint?test=1', method: :get, 'TEST_HEADER' => 'test header value') }
    subject(:adapter) { described_class.from_env(fake_request_env) }

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
      let(:fake_request_env) { ::Rack::MockRequest.env_for('http://www.dummy.com/endpoint?test=1', method: :get) }
      subject(:adapter) { described_class.from_env(fake_request_env, trace_parent: fake_trace_parent_parser) }

      it 'should be nil' do
        expect(subject.trace_id).to be_nil
      end
    end

    context 'with a traceparent header' do
      let(:fake_request_env) { ::Rack::MockRequest.env_for('http://www.dummy.com/endpoint?test=1', method: :get, 'HTTP_TRACEPARENT' => 'traceparentheadervalue') }
      subject(:adapter) { described_class.from_env(fake_request_env, trace_parent: fake_trace_parent_parser) }

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
      let(:fake_request_env) { ::Rack::MockRequest.env_for('http://www.dummy.com/endpoint?test=1', method: :get) }
      subject(:adapter) { described_class.from_env(fake_request_env, trace_parent: fake_trace_parent_parser) }

      it 'should be nil' do
        expect(subject.span_id).to be_nil
      end
    end

    context 'with a traceparent header' do
      let(:fake_request_env) { ::Rack::MockRequest.env_for('http://www.dummy.com/endpoint?test=1', method: :get, 'HTTP_TRACEPARENT' => 'traceparentheadervalue') }
      subject(:adapter) { described_class.from_env(fake_request_env, trace_parent: fake_trace_parent_parser) }

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
      let(:fake_request_env) { ::Rack::MockRequest.env_for('http://www.dummy.com/endpoint?test=1', method: :get) }
      subject(:adapter) { described_class.from_env(fake_request_env, trace_parent: fake_trace_parent_parser) }

      it 'should be false' do
        expect(subject.trace_info?).to be false
      end
    end

    context 'with a traceparent header' do
      let(:fake_request_env) { ::Rack::MockRequest.env_for('http://www.dummy.com/endpoint?test=1', method: :get, 'HTTP_TRACEPARENT' => 'traceparentheadervalue') }
      subject(:adapter) { described_class.from_env(fake_request_env, trace_parent: fake_trace_parent_parser) }

      it 'should be true if parsed ok' do
        expect(subject.trace_info?).to be true
      end

      it 'returns false of the traceparent parser returned nil' do
        allow(fake_trace_parent_parser).to receive(:parse).and_return nil

        expect(subject.trace_info?).to be false
      end
    end
  end

end