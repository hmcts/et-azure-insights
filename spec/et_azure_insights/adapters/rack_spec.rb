# frozen_string_literal: true

require 'spec_helper'
require 'et_azure_insights/adapters/rack'
require 'et_azure_insights'
require 'rack/mock'
RSpec.describe EtAzureInsights::Adapters::Rack do
  include_context 'fake client'
  let(:fake_app_response) { [200, {}, 'app-body'] }
  let(:fake_app) { spy('Rack app', call: fake_app_response) }
  let(:fake_request_env) { Rack::MockRequest.env_for('http://www.dummy.com/endpoint?test=1') }
  subject(:rack) { described_class.new(fake_app) }

  describe '#call' do
    it 'calls the app' do
      rack.call(fake_request_env, client: fake_client)

      expect(fake_app).to have_received(:call).with(fake_request_env)
    end

    it 'returns what the app returns' do
      result = rack.call(fake_request_env, client: fake_client)

      expect(result).to eq fake_app_response
    end

    it 'calls track_request on the telemetry client' do
      rack.call(fake_request_env, client: fake_client)

      expect(fake_client).to have_received(:track_request)
    end

    it 'calls track_request with the correct request id' do
      rack.call(fake_request_env, client: fake_client)

      expect(fake_client).to have_received(:track_request).with(match(/\A\|[0-9a-f]{32}\.[0-9a-f]{16}\.\z/), anything, anything, anything, anything, anything)
    end

    it 'calls track_request with the correct status' do
      rack.call(fake_request_env, client: fake_client)

      expect(fake_client).to have_received(:track_request).with(anything, anything, anything, '200', anything, anything)
    end

    it 'calls track_request with the correct operation id' do
      expect(fake_app).to receive(:call) do |env|
        expect(fake_client_operation).to have_received(:id=).with(match(/\A\|[0-9a-f]{32}\./))
        fake_app_response
      end
      rack.call(fake_request_env, client: fake_client)
    end

    it 'calls track_request with the correct operation id supplied from ActionDispatch::RequestId middleware if in use in rails or similar environment' do
      expect(fake_app).to receive(:call) do |env|
        expect(fake_client_operation).to have_received(:id=).with('|c1b40e908df64ed1b27e4344c2557642.')
        fake_app_response
      end
      rack.call(fake_request_env.merge('action_dispatch.request_id' => 'c1b40e90-8df6-4ed1-b27e-4344c2557642'), client: fake_client)
    end

    it 'sets the operation parent id set to the request id' do
      expected_request_id = nil
      expect(fake_app).to receive(:call) do |env|
        expect(fake_client_operation).to have_received(:parent_id=) do |val|
          expected_request_id = val
        end
        fake_app_response
      end
      subject.call(fake_request_env, client: fake_client)
      expect(fake_client).to have_received(:track_request).with(expected_request_id, anything, anything, anything, anything, anything)

    end

    it 'calls track_request with the correct operation name' do
      expect(fake_app).to receive(:call) do |env|
        expect(fake_client_operation).to have_received(:name=).with('GET /endpoint')
        fake_app_response
      end

      rack.call(fake_request_env, client: fake_client)
    end

    context 'error handling when error is raised in app' do
      it 'calls track_exception on the telemetry client with the exception if the app raises an exception' do
        allow(fake_app).to receive(:call).and_raise(RuntimeError, 'Fake error message')
        begin
          rack.call(fake_request_env, client: fake_client)
        rescue StandardError
          RuntimeError
        end

        expect(fake_client).to have_received(:track_exception)
          .with(an_instance_of(RuntimeError).and(have_attributes(message: 'Fake error message')),)
      end

      it 'calls track_exception on the telemetry client with the correct context if the app raises an exception' do
        allow(fake_app).to receive(:call).and_raise(RuntimeError, 'Fake error message')
        begin
          rack.call(fake_request_env, client: fake_client)
        rescue StandardError
          RuntimeError
        end

        expect(fake_client_operation).to have_received(:id=).with(match(/\A\|[0-9a-f]{32}\./)).at_least(:once)
        expect(fake_client).to have_received(:track_exception)
      end

      it 'calls track_request on the telemetry client even after an exception but with success of false' do
        allow(fake_app).to receive(:call).and_raise(RuntimeError, 'Fake error message')
        begin
          rack.call(fake_request_env, client: fake_client)
        rescue StandardError
          RuntimeError
        end

        expect(fake_client).to have_received(:track_request).with(anything, anything, anything, '500', false, anything)
      end

      it 're raises the original exception' do
        allow(fake_app).to receive(:call).and_raise(RuntimeError, 'Fake error message')

        expect { rack.call(fake_request_env, client: fake_client) }.to raise_exception(RuntimeError, 'Fake error message')
      end

      it 'keeps the original current span from before the call' do
        allow(fake_app).to receive(:call).and_raise(RuntimeError, 'Fake error message')
        original_span = EtAzureInsights::Correlation::Span.current

        begin
          rack.call(fake_request_env, client: fake_client)
        rescue StandardError
          RuntimeError
        end
        expect(EtAzureInsights::Correlation::Span.current).to be original_span
      end
    end

    context 'error handling when error has been caught upstream so is not raised' do
      let(:fake_app_response) { [500, {}, 'Fake error message'] }
      it 'calls track_exception on the telemetry client with the exception if the app raises an exception' do
        rack.call(fake_request_env, client: fake_client)

        expect(fake_client).to have_received(:track_exception)
          .with(an_instance_of(RuntimeError).and(have_attributes(message: 'Fake error message')))
      end

      it 'calls track_exception on the telemetry client with the correct context if the app raises an exception' do
        rack.call(fake_request_env, client: fake_client)

        expect(fake_client_operation).to have_received(:id=).with(match(/\A\|[0-9a-f]{32}\./)).at_least(:once)
        expect(fake_client).to have_received(:track_exception)
      end

      it 'calls track_request on the telemetry client even after an exception but with success of false' do
        rack.call(fake_request_env, client: fake_client)

        expect(fake_client).to have_received(:track_request).with(anything, anything, anything, '500', false, anything)
      end

      it 'keeps the original current span from before the call' do
        original_span = EtAzureInsights::Correlation::Span.current

        rack.call(fake_request_env, client: fake_client)
        expect(EtAzureInsights::Correlation::Span.current).to be original_span
      end
    end

    context 'with traceparent header set suggesting this has been called by something else' do
      # Some rules
      # The request id contains |<root>.<parent>.<this-request-id>.
      # The operation id is just |<root>|
      # The parent id for the operation is |<root>.<parent>.
      let(:fake_traceparent) { '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01' }
      let(:fake_request_env) { Rack::MockRequest.env_for('http://www.dummy.com/endpoint?test=1', 'HTTP_TRACEPARENT' => fake_traceparent) }
      it 'calls track_dependency with the current operation data set' do
        rack.call(fake_request_env, client: fake_client)

        expect(fake_client_operation).to have_received(:id=).with('|4bf92f3577b34da6a3ce929d0e0e4736.').at_least(:once)
        expect(fake_client_operation).to have_received(:parent_id=).with('|4bf92f3577b34da6a3ce929d0e0e4736.00f067aa0ba902b7.')
        expect(fake_client_operation).to have_received(:name=).with('GET /endpoint').at_least(:once)
        expect(fake_client).to have_received(:track_request)
      end

      it 'calls track_dependency with the request id in the correct format' do
        rack.call(fake_request_env, client: fake_client)

        expect(fake_client).to have_received(:track_request).with(match(/\A\|[0-9a-f]{32}\.[0-9a-f]{16}\.\z/), anything, anything, anything, anything, anything)
      end

      it 'calls track_dependency with the request id that does not end with the parent' do
        rack.call(fake_request_env, client: fake_client)

        expect(fake_client).to have_received(:track_request).with(satisfy {|s| !s.end_with?('00f067aa0ba902b7.')}, anything, anything, anything, anything, anything)
      end
    end
  end
end
