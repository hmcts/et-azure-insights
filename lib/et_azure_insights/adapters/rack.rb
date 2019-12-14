# frozen_string_literal: true

require 'et_azure_insights/client'
require 'et_azure_insights/client_helper'
require 'rack/request'
module EtAzureInsights
  module Adapters
    # A rack middleware to be used in rails and other rack applications.
    # This will resolve the parent span for correlation as well as
    # sorting out error handling and ensuring the span stays correct
    # when errors happen.
    class Rack
      include EtAzureInsights::ClientHelper
      def initialize(app, config: EtAzureInsights.config,
                     correlation_request: EtAzureInsights::RequestAdapter::Rack,
                     correlation_span: EtAzureInsights::Correlation::Span)
        self.config = config
        self.app = app
        self.correlation_request = correlation_request
        self.correlation_span = correlation_span
      end

      def call(env, client: EtAzureInsights::Client.client)
        meta = {}
        response = call_and_record(env, meta, client)
        send_exception_telemetry(meta[:exception], client) unless meta[:exception].nil?
        send_request_telemetry(env, response, meta[:start], meta[:duration], client)
        raise meta[:exception] if meta[:exception] && meta[:raise_exception]

        response
      end

      private

      def call_and_record(env, meta, client)
        request = correlation_request.from_env(env)
        with_correlation(env) do |span|
          span.open name: request.name, id: generate_span_id do |child_span|
            env['et_azure_insights.span_path'] = child_span.path
            configure_telemetry_from_span(request, child_span, client)
            result = call_app_with_error_handler(env, meta)
            configure_telemetry_from_span(request, span, client)
            result
          end
        end
      end

      def configure_telemetry_from_span(request, span, client)
        span_path = span.path
        operation_id = "|#{span_path.first}."
        operation_parent_id = span_path.empty? ? nil : "|#{span_path.join('.')}."
        configure_telemetry_context!(operation_id: operation_id, operation_parent_id: operation_parent_id, operation_name: request.name, client: client)
      end

      def call_app_with_error_handler(env, meta)
        meta[:start] = Time.now
        response = app.call(env)
        meta[:duration] = Time.now - meta[:start]
        generate_fake_exception(meta, response)
        response
      rescue Exception => e # rubocop:disable Lint/RescueException
        meta[:exception] = e
        meta[:duration] = Time.now - meta[:start]
        meta[:raise_exception] = true
        [500, {}, e.message]
      end

      def generate_fake_exception(meta, response)
        return unless response.first > 499

        meta[:exception] = RuntimeError.new(response.last)
        meta[:raise_exception] = false
      end

      attr_accessor :config, :app, :correlation_request, :correlation_span

      def with_correlation(env, &block)
        request = correlation_request.from_env(env)
        if request.trace_info?
          # Open a span representing the external trace info
          within_parent_correlation_span(request, &block)
        else
          within_new_correlation_span(&block)
        end
      end

      def within_new_correlation_span(&block)
        correlation_span.current.open name: 'operation', id: generate_trace_id, &block
      end

      def within_parent_correlation_span(request, &block)
        correlation_span.current.open name: 'external operation', id: request.trace_id do |span|
          span.open name: 'external child correlation', id: request.span_id, &block
        end
      end

      def generate_span_id
        SecureRandom.hex(8)
      end

      def generate_trace_id
        SecureRandom.hex(16)
      end

      def send_request_telemetry(env, response, start, duration, client)
        span_path = env['et_azure_insights.span_path']
        request_id = span_path.length > 1 ? "|#{span_path.first}.#{span_path.last}." : "|#{span_path.first}."
        start_time = start.iso8601(7)
        formatted_duration = format_request_duration(duration)
        status = response.first
        success = status < 400
        options = options_hash(env)
        client.track_request(request_id, start_time, formatted_duration, status.to_s, success, options)
      end

      def send_exception_telemetry(exception, client)
        client.track_exception(exception)
      end

      def options_hash(env)
        request = ::Rack::Request.new env
        {
          name: "#{request.request_method} #{request.path}",
          http_method: request.request_method,
          url: request.url
        }
      end
    end
  end
end
