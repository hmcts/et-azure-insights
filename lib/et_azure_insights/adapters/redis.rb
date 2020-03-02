# frozen_string_literal: true

module EtAzureInsights
  module Adapters
    # An adapter to hook into and process typhoeus requests / responses and send
    # them on as a dependency to insights
    class Redis
      def self.setup(redis_client: ::Redis::Client, config: EtAzureInsights.config, client: ClientBuilder.new(config: config).build)
        redis_client.class_eval do
          alias_method :call_without_azure_insights, :call

          def call(*args, &block)
            url = "#{scheme}://#{host}:#{port}"
            ::EtAzureInsights::Adapters::Redis.instance.call(*args, url) do
              call_without_azure_insights(*args, &block)
            end
          end

          alias_method :call_pipeline_without_azure_insights, :call_pipeline

          def call_pipeline(*args, &block)
            url = "#{scheme}://#{host}:#{port}"
            ::EtAzureInsights::Adapters::Redis.instance.call_pipeline(*args, url) do
              call_pipeline_without_azure_insights(*args, &block)
            end
          end

          alias_method :connect_without_azure_insights, :connect

          def connect(*args, &block)
            url = "#{scheme}://#{host}:#{port}"
            ::EtAzureInsights::Adapters::Redis.instance.connect(*args, url) do
              connect_without_azure_insights(*args, &block)
            end
          end
        end
      end

      def self.uninstall(redis_client: ::Redis::Client)
        redis_client.class_eval do
          alias_method :call, :call_without_azure_insights
          alias_method :call_pipeline, :call_pipeline_without_azure_insights
          alias_method :connect, :connect_without_azure_insights
          remove_method :call_without_azure_insights
          remove_method :call_pipeline_without_azure_insights
          remove_method :connect_without_azure_insights
        end
      end

      def self.instance
        Thread.current[:azure_insights_redis_adapter_instance] ||= new
      end

      def initialize(config: EtAzureInsights.config, correlation_span: EtAzureInsights::Correlation::Span,
                     trace_parent: EtAzureInsights::TraceParent, logger: EtAzureInsights.logger)
        self.config = config
        self.correlation_span = correlation_span
        self.trace_parent = trace_parent
        self.enabled = true
        self.logger = logger
      end

      def call(*args, base_url, client: EtAzureInsights::Client.client, &block)
        return yield if should_skip?
        command = args[0]
        correlate(format_command(command)) do |span|
          start = Time.now
          response = execute(&block)
          duration = Time.now - start
          send_to_client *args, span, format_command(command), duration, base_url, response, client: client
          response
        end
      end

      def call_pipeline(*args, base_url, client: EtAzureInsights::Client.client, &block)
        return yield if should_skip?
        pipeline = args[0]
        correlate(format_pipeline_commands(pipeline.commands)) do |span|
          start = Time.now
          response = execute(&block)
          duration = Time.now - start
          send_to_client *args, span, format_pipeline_commands(pipeline.commands), duration, base_url, response, client: client
          response
        end
      end

      def connect(*args, base_url, client: EtAzureInsights::Client.client, &block)
        return yield if should_skip?
        correlate('connect') do |span|
          start = Time.now
          response = execute(&block)
          duration = Time.now - start
          send_to_client *args, span, 'connect', duration, base_url, response, client: client
          response
        end
      end


      private

      attr_accessor :config, :correlation_span, :trace_parent, :enabled, :logger

      def should_skip?
        !enabled
      end

      def execute(&block)
        yield
      rescue Exception => ex
        ex
      end

      def send_to_client(*args, span, data, duration, base_url, response, client:)
        success = !response.is_a?(Exception)
        client.track_dependency id_from_span(span),
                                format_request_duration(duration),
                                success ? '200' : '500',
                                success,
                                target: base_url,
                                name: data,
                                type: 'redis',
                                data: data

      end

      def format_pipeline_commands(commands)
        commands.map(&method(:format_command)).join(', ')
      end

      def format_command(command)
        command[0]
      end

      def within_operation_span(&block)
        if correlation_span.current.root?
          correlation_span.current.open id: SecureRandom.hex(16), name: 'Unknown Operation', &block
        else
          yield correlation_span.current
        end
      end

      def correlate(command, &block)
        within_operation_span do |op_span|
          op_span.open id: SecureRandom.hex(8), name: command, &block
        end
      end

      def format_request_duration(duration_seconds)
        if duration_seconds >= 86_400
          # just return 1 day when it takes more than 1 day which should not happen for requests.
          return '01.00:00:00.0000000'
        end

        Time.at(duration_seconds).gmtime.strftime('00.%H:%M:%S.%7N')
      end

      def id_from_span(span)
        span_path = span.path
        span_path.length > 1 ? "|#{span_path.first}.#{span_path.last}." : "|#{span_path.first}."
      end
    end
  end
end
