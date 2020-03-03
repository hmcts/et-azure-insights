require 'sidekiq'
require 'et_azure_insights/config'
require 'et_azure_insights/client'
require 'et_azure_insights/client_helper'
require 'et_azure_insights/correlation'
require 'et_azure_insights/request_adapter/sidekiq_job'
require 'et_azure_insights/request_adapter/active_job_job'
module EtAzureInsights
  module Adapters
    class SidekiqServer
      include EtAzureInsights::ClientHelper
      def self.setup(sidekiq_config: ::Sidekiq)
        sidekiq_config.server_middleware do |chain|
          chain.add self
        end
      end

      def self.uninstall(sidekiq_config: ::Sidekiq)
        sidekiq_config.server_middleware do |chain|
          chain.remove self
        end
      end

      def initialize(config: EtAzureInsights::Config.config,
                     correlation_span: EtAzureInsights::Correlation::Span,
                     sidekiq_job_request_adapter: EtAzureInsights::RequestAdapter::SidekiqJob,
                     activejob_job_request_adapter: EtAzureInsights::RequestAdapter::ActiveJobJob)
        self.config = config
        self.correlation_span = correlation_span
        self.sidekiq_job_request_adapter = sidekiq_job_request_adapter
        self.activejob_job_request_adapter = activejob_job_request_adapter
      end

      def call(_worker, job_hash, _queue, client: EtAzureInsights::Client.client, &block)
        request = request_adapter_for(job_hash).from_job_hash(job_hash)
        meta = {}
        response = with_correlation(request) do |span|
          span.open name: request.name, id: generate_span_id do |child_span|
            meta[:span_to_report] = child_span
            configure_telemetry_from_span(request, child_span, client)
            result = execute_worker(meta, &block)
            configure_telemetry_from_span(request, span, client)
            result
          end
        end
        send_request_telemetry(meta[:span_to_report], request, response, meta[:start], meta[:duration], client)
        return response unless response.is_a?(Exception)

        send_exception_telemetry(response, client)
        raise response
      end

      private

      def execute_worker(meta)
        meta[:start] = Time.now
        yield
      rescue Exception => e
        e
      ensure
        meta[:duration] = Time.now - meta[:start]
      end


      attr_accessor :config, :correlation_span, :sidekiq_job_request_adapter, :activejob_job_request_adapter

      def request_adapter_for(job)
        if job['class'] == 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper'
          activejob_job_request_adapter
        else
          sidekiq_job_request_adapter
        end
      end

      def with_correlation(request, &block)
        if request.trace_info?
          # Open a span representing the external trace info
          within_parent_correlation_span(request, &block)
        else
          within_new_correlation_span(request, &block)
        end
      end

      def within_new_correlation_span(request, &block)
        correlation_span.current.open name: 'operation', id: request.request_id, &block
      end

      def within_parent_correlation_span(request, &block)
        correlation_span.current.open name: 'external operation', id: request.trace_id do |span|
          span.open name: 'external child correlation', id: request.span_id, &block
        end
      end

      def generate_span_id
        SecureRandom.hex(8)
      end

      def configure_telemetry_from_span(request, span, client)
        span_path = span.path
        operation_id = "|#{span_path.first}."
        operation_parent_id = span_path.empty? ? nil : "|#{span_path.first}.#{span_path.last}."
        configure_telemetry_context!(operation_id: operation_id, operation_parent_id: operation_parent_id, operation_name: request.name, client: client)
      end

      def send_request_telemetry(span, request, response_or_ex, start, duration, client)
        is_exception = response_or_ex.is_a?(Exception)
        span_path = span.path
        request_id = span_path.length > 1 ? "|#{span_path.first}.#{span_path.last}." : "|#{span_path.first}."
        start_time = start.iso8601(7)
        formatted_duration = format_request_duration(duration)
        status = is_exception ? 500 : 200
        success = !is_exception
        options = options_hash(request)
        client.track_request(request_id, start_time, formatted_duration, status.to_s, success, options)
      end

      def send_exception_telemetry(exception, client)
        client.track_exception(exception)
      end

      def options_hash(request)
        {
          name: request.name,
          http_method: request.request_method.to_s.upcase,
          url: request.url
        }
      end

    end
  end
end