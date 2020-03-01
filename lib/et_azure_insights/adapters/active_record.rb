# frozen_string_literal: true

module EtAzureInsights
  module Adapters
    # An adapter to hook into and process typhoeus requests / responses and send
    # them on as a dependency to insights
    class ActiveRecord
      def self.setup(notifications: ::ActiveSupport::Notifications, config: EtAzureInsights.config, request_stack: EtAzureInsights::RequestStack)
        @sub = notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
          duration = finish - start
          instance.call(payload, duration)
        end
      end

      def self.uninstall(notifications: ::ActiveSupport::Notifications)
        notifications.unsubscribe(@sub) unless @sub.nil?
      end

      def self.instance
        Thread.current[:azure_insights_active_record_adapter] ||= new
      end

      def call(payload, duration)
        return if should_skip?(payload)
        correlate payload do |span|
          send_to_client(span, payload, duration)
        end
      end

      def initialize(config: EtAzureInsights.config, correlation_span: EtAzureInsights::Correlation::Span,
                     trace_parent: EtAzureInsights::TraceParent, logger: EtAzureInsights.logger)
        self.config = config
        self.correlation_span = correlation_span
        self.trace_parent = trace_parent
        self.enabled = true
        self.logger = logger
      end

      private

      attr_accessor :config, :request_stack, :correlation_span, :trace_parent, :enabled, :logger

      def should_skip?(payload)
        !enabled || payload[:cache]
      end

      def send_to_client(span, payload, duration, client: ::EtAzureInsights::Client.client)
        client.track_dependency id_from_span(span),
                                format_request_duration(duration),
                                '200',
                                true,
                                target: target_from(payload),
                                type: type_from(payload),
                                name: payload[:sql],
                                data: payload[:sql]
      end

      def type_from(payload)
        payload[:connection].adapter_name
      end

      def target_from(payload)
        # @TODO This is not ideal, but is all we've got for now.  Need to find a more supported way of getting this information
        # it will probably be different for different database types as well
        low_level_connection = payload[:connection].instance_variable_get(:@connection)
        "#{low_level_connection.try(:host)}:#{low_level_connection.try(:port)}"
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

      def within_operation_span(&block)
        if correlation_span.current.root?
          correlation_span.current.open id: SecureRandom.hex(16), name: 'Unknown Operation', &block
        else
          yield correlation_span.current
        end
      end

      def correlate(payload, &block)
        within_operation_span do |op_span|
          op_span.open id: SecureRandom.hex(8), name: payload[:sql], &block
        end
      end
    end
  end
end
