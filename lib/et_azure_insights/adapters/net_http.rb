# frozen_string_literal: true

module EtAzureInsights
  module Adapters
    # An adapter to hook into and process typhoeus requests / responses and send
    # them on as a dependency to insights
    class NetHttp
      def self.setup(net_http: ::Net::HTTP, config: EtAzureInsights.config, client: ClientBuilder.new(config: config).build)
        net_http.class_eval do
          def request_with_azure_insights_instrumentor(request, *args, &block)
            ::EtAzureInsights::Adapters::NetHttp.instance.call(request, self) do
              request_without_azure_insights_instrumentor(request, *args, &block)
            end
          end
          alias request_without_azure_insights_instrumentor request
          alias request request_with_azure_insights_instrumentor
        end
      end

      def self.instance
        Thread.current[:azure_insights_net_http_adapter_instance] ||= new
      end

      def initialize(config: EtAzureInsights.config, client: ClientBuilder.new(config: config).build, request_stack: EtAzureInsights::RequestStack)
        self.config = config
        self.client = client
        self.request_stack = request_stack
      end

      def call(request, http, *args)
        start = Time.now
        response = yield
        duration = Time.now - start
        send_to_client request, response, http, duration
        response
      end

      private

      attr_accessor :config, :client, :request_stack

      def send_to_client(request, response, http, duration)
        return if http.address =~ /dc\.services\.visualstudio\.com/  # Dont track our own !!
        request_url = URI.parse("#{http.use_ssl? ? 'https' : 'http'}://#{http.address}:#{http.port}#{request.path}").to_s
        with_request_id do
          request_id = request_stack.last
          if (200..299).include? response.code.to_i
            client.track_dependency request_id,
                                    format_request_duration(duration),
                                    response.code,
                                    true,
                                    target: request_url,
                                    name: "#{request.method} #{request_url}",
                                    type: 'HTTP',
                                    data: "#{request.method} #{request_url}"
          end

        end
      end

      def format_request_duration(duration_seconds)
        if duration_seconds >= 86_400
          # just return 1 day when it takes more than 1 day which should not happen for requests.
          return '01.00:00:00.0000000'
        end

        Time.at(duration_seconds).gmtime.strftime('00.%H:%M:%S.%7N')
      end

      def with_request_id(&block)
        request_id = "net_http-#{SecureRandom.uuid}"
        request_stack.for_request(request_id, &block)
      end
    end
  end
end
