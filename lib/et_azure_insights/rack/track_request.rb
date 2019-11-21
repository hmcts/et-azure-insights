# frozen_string_literal: true

require 'application_insights'
module EtAzureInsights
  module Rack
    # Track every request and sends the request data to application insights.
    # Also tracks the request id in the session for use as a 'parent_id'
    # when other data is sent to application insights.
    class TrackRequest < ::ApplicationInsights::Rack::TrackRequest
      def initialize(app, config: EtAzureInsights.config, request_stack: EtAzureInsights::RequestStack)
        self.config = config
        self.request_stack = request_stack
        super(app, config.insights_key, config.buffer_size, config.send_interval)
      end

      def self.current_request_id
        Thread.current[:azure_insights_rack_request_id]
      end

      def call(env)
        with_request_id env do
          start = Time.now
          retval = call_app_with_rescue(env)
          stop = Time.now
          send_request(env, request_stack.last, start, retval.is_a?(Exception) ? 500 : retval.first, stop)
          track_and_raise_exception(retval)
        end
      end

      private

      def call_app_with_rescue(env)
        @app.call(env)
      rescue Exception => e # rubocop:disable Lint/RescueException
        e
      end

      def with_request_id(env, &block)
        # Build a request ID, incorporating one from our request if one exists.
        request_id = request_id_header(env['HTTP_REQUEST_ID'])
        env['ApplicationInsights.request.id'] = request_id
        request_stack.for_request(request_id, &block)
      end

      def send_request(env, request_id, start, status, stop)
        start_time = start.iso8601(7)
        duration = format_request_duration(stop - start)
        success = status.to_i < 400

        request = ::Rack::Request.new env
        options = options_hash(request)

        data = request_data(request_id, start_time, duration, status, success, options)
        context = telemetry_context(request_id, env['HTTP_REQUEST_ID'])

        @client.channel.write data, context, start_time
      end

      def track_and_raise_exception(value)
        return value unless value.is_a?(Exception)

        client.track_exception value, handled_at: 'Unhandled'
        raise value
      end

      attr_accessor :config, :request_stack

      def telemetry_context(request_id, request_id_header)
        context = setup_context
        setup_operation(context, request_id, request_id_header)
        setup_cloud(context)
        context
      end

      def setup_cloud(context)
        context.cloud.role_name = config.insights_role_name unless config.insights_role_name.nil?
        context.cloud.role_instance = config.insights_role_instance unless config.insights_role_instance.nil?
      end

      def setup_operation(context, request_id, request_id_header)
        context.operation.id = operation_id(request_id)
        context.operation.parent_id = request_id_header
      end

      def setup_context
        context = Channel::TelemetryContext.new
        context.instrumentation_key = @instrumentation_key
        context
      end
    end
  end
end
