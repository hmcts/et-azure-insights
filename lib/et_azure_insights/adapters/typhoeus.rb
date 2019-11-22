# frozen_string_literal: true

module EtAzureInsights
  module Adapters
    # An adapter to hook into and process typhoeus requests / responses and send
    # them on as a dependency to insights
    class Typhoeus
      def call(request)
        start = Time.now
        request.on_complete do |response|
          duration = Time.now - start
          send_to_client(request, response, duration)
        end
      end

      def self.setup(typhoeus: ::Typhoeus, config: EtAzureInsights.config, client: ClientBuilder.new(config: config).build)
        instance = new(config: config, client: client)
        typhoeus.before do |request|
          instance.call(request)
          true
        end
        instance
      end

      private

      attr_accessor :config, :client, :request_stack

      def initialize(config: EtAzureInsights.config, client: ClientBuilder.new(config: config).build, request_stack: EtAzureInsights::RequestStack)
        self.config = config
        self.client = client
        self.request_stack = request_stack
      end

      def send_to_client(request, response, duration)
        with_request_id do
          request_id = request_stack.last
          if response.success?
            client.track_dependency request_id,
                                    format_request_duration(duration),
                                    response.response_code.to_s,
                                    true,
                                    target: request.url,
                                    name: "#{request.options[:method].to_s.upcase} #{request.url}",
                                    type: 'HTTP',
                                    data: 'unsurewhattoputhere'
          elsif response.timed_out?

          elsif response.failure?

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
        request_id = "typhoeus-#{SecureRandom.uuid}"
        request_stack.for_request(request_id, &block)
      end
    end
  end
end
