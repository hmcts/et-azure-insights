# frozen_string_literal: true

module EtAzureInsights
  module Adapters
    # An adapter to hook into and process typhoeus requests / responses and send
    # them on as a dependency to insights
    class Excon
      def self.setup(excon: ::Excon)
        excon.defaults[:middlewares] << self
      end

      def self.uninstall(excon: ::Excon)
        excon.defaults[:middlewares].reject! { |middleware| middleware == self }
      end

      def error_call(datum)
        # do stuff
        @stack.error_call(datum)
        end_correlation(datum)
      end

      def request_call(datum)
        self.start_time = Time.now
        start_correlation(datum)
        datum[:headers]['traceparent'] = trace_parent.from_span(request_span).to_s
        @stack.request_call(datum)
      end

      def response_call(datum, client: EtAzureInsights::Client.client)
        @stack.response_call(datum).tap do
          duration = Time.now - start_time
          send_to_client(client, datum, duration)
          end_correlation(datum)
        end
      end

      def initialize(stack, config: EtAzureInsights.config, correlation_span: EtAzureInsights::Correlation::Span,
                     trace_parent: EtAzureInsights::TraceParent,
                     logger: EtAzureInsights.logger)
        self.config = config
        self.correlation_span = correlation_span
        self.trace_parent = trace_parent
        self.enabled = true
        self.logger = logger
        self.stack = stack
      end

      private

      attr_accessor :config, :stack, :correlation_span, :trace_parent, :enabled,
                    :logger, :start_time, :request_span, :starting_span, :operation_span


      def send_to_client(client, datum, duration)
        query = datum[:query].nil? ? '' : "?#{datum[:query]}"
        request_uri = URI.parse("#{datum[:scheme]}://#{datum[:host]}:#{datum[:port]}#{datum[:path]}#{query}")
        client.track_dependency id_from_request_span,
                                format_request_duration(duration),
                                datum.dig(:response, :status).to_s,
                                (200..399).include?(datum.dig(:response, :status)),
                                target: target_for(request_uri), type: 'Http (tracked component)',
                                name: "#{datum[:method].upcase} #{request_uri}",
                                data: "#{datum[:method].upcase} #{request_uri}"
      end

      def id_from_request_span
        span_path = request_span.path
        span_path.length > 1 ? "|#{span_path.first}.#{span_path.last}." : "|#{span_path.first}."
      end

      def target_for(request_uri)
        components = [request_uri.host]
        components << request_uri.port unless request_uri.port == request_uri.default_port
        components.join(':')
      end

      def open_operation_span(&block)
        self.operation_span = if correlation_span.current.root?
                                correlation_span.current.open id: SecureRandom.hex(16), name: 'Unknown Operation'
                              else
                                correlation_span.current
                              end
      end

      def start_correlation(datum)
        self.starting_span = correlation_span.current
        open_operation_span
        request_path = datum[:path]
        request_path = '/' if request_path == ''
        open_request_span(datum, request_path)
      end

      def end_correlation(datum)
        until correlation_span.current.equal?(starting_span) do
          correlation_span.current.close
        end
      end

      def close_request_span
        request_span.close
      end

      def open_request_span(datum, request_path)
        self.request_span = operation_span.open id: SecureRandom.hex(8), name: "#{datum[:method].to_s.upcase} #{request_path}"
      end

      def format_request_duration(duration_seconds)
        if duration_seconds >= 86_400
          # just return 1 day when it takes more than 1 day which should not happen for requests.
          return '01.00:00:00.0000000'
        end

        Time.at(duration_seconds).gmtime.strftime('00.%H:%M:%S.%7N')
      end
    end
  end
end
