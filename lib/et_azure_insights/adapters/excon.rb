# frozen_string_literal: true

module EtAzureInsights
  module Adapters
    # An adapter to hook into and process typhoeus requests / responses and send
    # them on as a dependency to insights
    class Excon
      def self.setup(excon: ::Excon, config: EtAzureInsights.config, client: ClientBuilder.new(config: config).build)
        excon.defaults[:middlewares] << self
      end

      def error_call(datum)
        # do stuff
        @stack.error_call(datum)
      end

      def request_call(datum)
        # do stuff
        @stack.request_call(datum)
      end

      def response_call(datum)
        start = Time.now
        @stack.response_call(datum).tap do
          duration = Time.now - start
          send_to_client(datum, duration)
        end
      end

      def initialize(stack, config: EtAzureInsights.config, client: ClientBuilder.new(config: config).build, request_stack: EtAzureInsights::RequestStack)
        self.config = config
        self.client = client
        self.request_stack = request_stack
        self.stack = stack
      end

      private

      attr_accessor :config, :client, :request_stack, :stack


      def send_to_client(datum, duration)
        with_request_id do
          request_id = request_stack.last
          query = datum[:query].nil? ? '' : "?#{datum[:query]}"
          request_url = URI.parse("#{datum[:scheme]}://#{datum[:host]}:#{datum[:port]}#{datum[:path]}#{query}").to_s
          if (200..399).include?(datum.dig(:response, :status))
            client.track_dependency request_id,
                                    format_request_duration(duration),
                                    datum.dig(:response, :status).to_s,
                                    true,
                                    target: request_url,
                                    name: "#{datum[:method]} #{request_url}",
                                    type: 'HTTP',
                                    data: "#{datum[:method]} #{request_url}"
          else
            raise "Not yet implemented"
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
        request_id = "excon-#{SecureRandom.uuid}"
        request_stack.for_request(request_id, &block)
      end
    end
  end
end
