require 'sidekiq'
require 'et_azure_insights/config'
require 'et_azure_insights/request_adapter/sidekiq_job'
require 'et_azure_insights/request_adapter/active_job_job'
require 'et_azure_insights/client_helper'
module EtAzureInsights
  module Adapters
    class SidekiqClient
      include EtAzureInsights::ClientHelper
      def self.setup
        ::Sidekiq.default_configuration.client_middleware do |chain|
          chain.add self
        end
      end

      def self.uninstall
        ::Sidekiq.default_configuration.client_middleware do |chain|
          chain.remove self
        end
      end

      def initialize(config: EtAzureInsights::Config.config,
                     correlation_span: EtAzureInsights::Correlation::Span,
                     trace_parent: EtAzureInsights::TraceParent,
                     sidekiq_job_request_adapter: EtAzureInsights::RequestAdapter::SidekiqJob,
                     activejob_job_request_adapter: EtAzureInsights::RequestAdapter::ActiveJobJob)
        self.correlation_span = correlation_span
        self.trace_parent = trace_parent
        self.sidekiq_job_request_adapter = sidekiq_job_request_adapter
        self.activejob_job_request_adapter = activejob_job_request_adapter
        self.logger = config.logger


      end

      def call(_worker_class, job, _queue, _redis_pool, client: EtAzureInsights::Client.client)
        request = request_adapter_for(job).from_job_hash(job)
        correlate request do |span|
          job['azure_insights_headers'] ||= {}
          job['azure_insights_headers']['traceparent'] = trace_parent.from_span(span).to_s
          start = Time.now
          yield.tap do |response|
            duration = Time.now - start
            send_to_client client, span, request, response, duration
          end
        end
      end

      private

      attr_accessor :trace_parent, :correlation_span, :sidekiq_job_request_adapter, :activejob_job_request_adapter, :logger

      def request_adapter_for(job)
        if job['class'] == 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper'
          activejob_job_request_adapter
        else
          sidekiq_job_request_adapter
        end
      end

      def within_operation_span(&block)
        if correlation_span.current.root?
          correlation_span.current.open id: SecureRandom.hex(16), name: 'Unknown Operation', &block
        else
          yield correlation_span.current
        end
      end

      def correlate(request, &block)
        within_operation_span do |op_span|
          op_span.open id: SecureRandom.hex(8), name: request.name, &block
        end
      end

      def send_to_client(client, span, request, response, duration)

        logger.debug("SidekiqClient Adapter sending to insights with operation named #{client.context.operation.name}")

        client.track_dependency id_from_span(span),
                                format_request_duration(duration),
                                response ? '200' : '500',
                                !!response,
                                type: 'Sidekiq (tracked component)',
                                name: request.name,
                                data: request.name
      end

      def id_from_span(span)
        span_path = span.path
        span_path.length > 1 ? "|#{span_path.first}.#{span_path.last}." : "|#{span_path.first}."
      end
    end
  end
end