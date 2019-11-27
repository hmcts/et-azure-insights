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

      def self.instance
        Thread.current[:azure_insights_redis_adapter_instance] ||= new
      end

      def initialize(config: EtAzureInsights.config, client: ClientBuilder.new(config: config).build, request_stack: EtAzureInsights::RequestStack)
        self.config = config
        self.client = client
        self.request_stack = request_stack
      end

      def call(*args, base_url)
        command = args[0]
        start = Time.now
        response = yield
        duration = Time.now - start
        send_to_client *args, format_command(command), duration, base_url
        response
      end

      def call_pipeline(*args, base_url)
        pipeline = args[0]
        start = Time.now
        response = yield
        duration = Time.now - start
        send_to_client *args, format_pipeline_commands(pipeline.commands), duration, base_url
        response
      end

      def connect(*args, base_url)
        start = Time.now
        response = yield
        duration = Time.now - start
        send_to_client *args, 'connect', duration, base_url
        response
      end


      private

      attr_accessor :config, :client, :request_stack

      def send_to_client(*args, data, duration, base_url)
        with_request_id do
          request_id = request_stack.last
          client.track_dependency request_id,
                                  format_request_duration(duration),
                                  '200',
                                  true,
                                  target: base_url,
                                  name: data,
                                  type: 'redis',
                                  data: data

        end
      end

      def format_pipeline_commands(commands)
        commands.map(&method(:format_command)).join(', ')
      end

      def format_command(command)
        command[0]
      end

      def format_request_duration(duration_seconds)
        if duration_seconds >= 86_400
          # just return 1 day when it takes more than 1 day which should not happen for requests.
          return '01.00:00:00.0000000'
        end

        Time.at(duration_seconds).gmtime.strftime('00.%H:%M:%S.%7N')
      end

      def with_request_id(&block)
        request_id = "redis-#{SecureRandom.uuid}"
        request_stack.for_request(request_id, &block)
      end
    end
  end
end
