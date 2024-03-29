# frozen_string_literal: true

module EtAzureInsights
  module Adapters
    # An adapter to hook into and process typhoeus requests / responses and send
    # them on as a dependency to insights
    class NetHttp
      module Patch
        def request(request, *args, &block)
          ::EtAzureInsights::Adapters::NetHttp.instance.call(request, self) do
            super(request, *args, &block)
          end
        end
      end

      def self.setup(net_http: ::Net::HTTP)
        net_http.send(:prepend, Patch) unless Net::HTTP.ancestors.include?(Patch)
      end

      def self.uninstall(net_http: ::Net::HTTP)

      end

      def self.instance
        Thread.current[:azure_insights_net_http_adapter_instance] ||= new
      end

      def initialize(correlation_span: EtAzureInsights::Correlation::Span,
                     trace_parent: EtAzureInsights::TraceParent, logger: EtAzureInsights.logger)
        self.correlation_span = correlation_span
        self.trace_parent = trace_parent
        self.enabled = true
        self.logger = logger
      end

      def call(request, http, client: EtAzureInsights::Client.client, &block)
        return yield if should_skip?(request, http)

        correlate request do |span|
          request['traceparent'] = trace_parent.from_span(span).to_s
          start = Time.now
          ret = execute(&block).tap do |response|
            duration = Time.now - start
            send_to_client client, span, request, response, http, duration
          end
          raise ret if ret.is_a?(Exception)
          ret
        end
      end

      private

      attr_accessor :correlation_span, :trace_parent, :enabled, :logger

      def should_skip?(request, http)
        !enabled || http.address =~ /dc\.services\.visualstudio\.com/ || request['et-azure-insights-no-track'] == 'true'
      end

      def execute
        original = enabled
        self.enabled = false
        yield
      rescue Exception => ex
        ex
      ensure
        self.enabled = original
      end

      def send_to_client(client, span, request, response, http, duration)
        logger.debug("NetHTTP Adapter sending to insights with operation named #{client.context.operation.name}")
        success = !response.is_a?(Exception) && (200..299).include?(response.code.to_i)
        code = response.is_a?(Exception) ? '500' : response.code
        request_uri = uri(http, request)
        client.track_dependency id_from_span(span),
                                format_request_duration(duration),
                                code,
                                success,
                                target: target_for(request_uri), type: 'Http (tracked component)',
                                name: "#{request.method} #{request_uri}",
                                data: "#{request.method} #{request_uri}"
      end

      def id_from_span(span)
        span_path = span.path
        span_path.length > 1 ? "|#{span_path.first}.#{span_path.last}." : "|#{span_path.first}."
      end

      def uri(http, request)
        URI.parse("#{http.use_ssl? ? 'https' : 'http'}://#{http.address}:#{http.port}#{request.path}")
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
          op_span.open id: SecureRandom.hex(8), name: "#{request.method} #{request.path}", &block
        end
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
