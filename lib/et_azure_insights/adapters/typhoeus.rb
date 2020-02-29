# frozen_string_literal: true

module EtAzureInsights
  module Adapters
    # An adapter to hook into and process typhoeus requests / responses and send
    # them on as a dependency to insights
    class Typhoeus
      def call(request, client: EtAzureInsights::Client.client)
        return yield if should_skip?(request)

        correlate request do |span|
          request.options[:headers]['traceparent'] = trace_parent.from_span(span).to_s
          start = Time.now
          request.on_complete do |response|
            duration = Time.now - start
            send_to_client client, span, request, response, duration
          end
        end
      end

      def self.setup(typhoeus: ::Typhoeus, config: EtAzureInsights.config)
        instance = new(config: config)
        typhoeus.before do |request|
          instance.call(request)
          true
        end
        instance
      end

      def self.uninstall(typhoeus: ::Typhoeus)
        typhoeus.before.reject! do |blk|
          blk.source_location.first == __FILE__
        end
      end

      private

      attr_accessor :config, :correlation_span, :trace_parent, :enabled, :logger

      def initialize(config: EtAzureInsights.config,
                     correlation_span: EtAzureInsights::Correlation::Span,
                     trace_parent: EtAzureInsights::TraceParent,
                     logger: EtAzureInsights.logger)
        self.config = config
        self.correlation_span = correlation_span
        self.trace_parent = trace_parent
        self.enabled = true
        self.logger = logger
      end

      def send_to_client(client, span, request, response, duration)
        request_uri = URI.parse(request.base_url)
        request_url = request_uri.path == '' ? "#{request_uri}/" : "#{request_uri}"
        client.track_dependency id_from_span(span),
                                format_request_duration(duration),
                                response.response_code.to_s,
                                response.success?,
                                target: target_for(request_uri), type: 'Http (tracked component)',
                                name: "#{request.options[:method].to_s.upcase} #{request_url}",
                                data: "#{request.options[:method].to_s.upcase} #{request_url}"
      end

      def id_from_span(span)
        span_path = span.path
        span_path.length > 1 ? "|#{span_path.first}.#{span_path.last}." : "|#{span_path.first}."
      end

      def target_for(request_uri)
        components = [request_uri.host]
        components << request_uri.port unless request_uri.port == request_uri.default_port
        components.join(':')
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
          request_path = URI.parse(request.base_url).path
          request_path = '/' if request_path == ''
          op_span.open id: SecureRandom.hex(8), name: "#{request.options[:method].to_s.upcase} #{request_path}", &block
        end
      end

      def format_request_duration(duration_seconds)
        if duration_seconds >= 86_400
          # just return 1 day when it takes more than 1 day which should not happen for requests.
          return '01.00:00:00.0000000'
        end

        Time.at(duration_seconds).gmtime.strftime('00.%H:%M:%S.%7N')
      end

      def should_skip?(request)
        !enabled || request.options[:headers]['et-azure-insights-no-track'] == 'true'
      end
    end
  end
end
