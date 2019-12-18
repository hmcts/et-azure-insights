# frozen_string_literal: true

require 'net/http'
module EtAzureInsights
  # A drop in replacement for ApplicationInsights::TelemetryClient
  # but supports extra features.
  class Client
    def self.client
      Thread.current[:azure_insights_global_client] ||= new
    end

    def initialize(config: EtAzureInsights.config, channel: EtAzureInsights.global_insights_channel)
      self.config = config
      self.channel = channel
      self.context = ApplicationInsights::Channel::TelemetryContext.new
      configure_role_instance
      configure_role_name
      configure_instrumentation_key
    end

    attr_reader :context

    # Send information about the page viewed in the application (a web page for
    # instance).
    # @param [String] name the name of the page that was viewed.
    # @param [String] url the URL of the page that was viewed.
    # @param [Hash] options the options to create the
    #   {Channel::Contracts::PageViewData} object.
    # @option options [Fixnum] :duration the duration of the page view in
    #   milliseconds. (defaults to: 0)
    # @option options [Hash] :properties the set of custom properties the client
    #   wants attached to this data item. (defaults to: {})
    # @option options [Hash] :measurements the set of custom measurements the
    #   client wants to attach to this data item (defaults to: {})
    def track_page_view(name, url, options = {})
      data_attributes = {
        name: name || 'Null',
        url: url,
        duration: options[:duration],
        properties: options[:properties] || {},
        measurements: options[:measurements] || {}
      }
      data = ApplicationInsights::Channel::Contracts::PageViewData.new data_attributes
      channel.write(data, context)
    end

    # Send information about a single exception that occurred in the application.
    # @param [Exception] exception the exception that the client wants to send.
    # @param [Hash] options the options to create the
    #   {Channel::Contracts::ExceptionData} object.
    # @option options [String] :handled_at the type of exception
    #   (defaults to: 'UserCode')
    # @option options [Hash] :properties the set of custom properties the client
    #   wants attached to this data item. (defaults to: {})
    # @option options [Hash] :measurements the set of custom measurements the
    #   client wants to attach to this data item (defaults to: {})
    def track_exception(exception, options = {})
      return unless exception.is_a? Exception

      parsed_stack = []
      if exception.backtrace
        frame_pattern = /^(?<file>.*):(?<line>\d+)(\.|:in `((?<method>.*)'$))/

        exception.backtrace.each_with_index do |frame, counter|
          match = frame_pattern.match frame
          stack_frame = Channel::Contracts::StackFrame.new(
            assembly: 'Unknown',
            file_name: match['file'],
            level: counter,
            line: match['line'],
            method: match['method']
          )

          parsed_stack << stack_frame
        end
      end

      details = Channel::Contracts::ExceptionDetails.new(
        id: 1,
        outer_id: 0,
        type_name: exception.class.name,
        message: exception.message,
        has_full_stack: !exception.backtrace.nil?,
        stack: (exception.backtrace&.join("\n")),
        parsed_stack: parsed_stack
      )

      data = Channel::Contracts::ExceptionData.new(
        exceptions: [details],
        properties: options[:properties] || {},
        measurements: options[:measurements] || {},
        # Must initialize handled_at after properties because it's actually stored in properties
        handled_at: options.fetch(:handled_at, 'UserCode')
      )

      channel.write(data, context)
    end

    # Send information about a single event that has occurred in the context of
    # the application.
    # @param [String] name the data to associate to this event.
    # @param [Hash] options the options to create the
    #   {Channel::Contracts::EventData} object.
    # @option options [Hash] :properties the set of custom properties the client
    #   wants attached to this data item. (defaults to: {})
    # @option options [Hash] :measurements the set of custom measurements the
    #   client wants to attach to this data item (defaults to: {})
    def track_event(name, options = {})
      data = Channel::Contracts::EventData.new(
        name: name || 'Null',
        properties: options[:properties] || {},
        measurements: options[:measurements] || {}
      )

      channel.write(data, context)
    end

    # Send information about a single metric data point that was captured for
    # the application.
    # @param [String] name the name of the metric that was captured.
    # @param [Fixnum] value the value of the metric that was captured.
    # @param [Hash] options the options to create the
    #   {Channel::Contracts::MetricData} object.
    # @option options [Channel::Contracts::DataPointType] :type the type of the
    #   metric (defaults to: {Channel::Contracts::DataPointType::AGGREGATION})
    # @option options [Fixnum] :count the number of metrics that were aggregated
    #   into this data point (defaults to: 0)
    # @option options [Fixnum] :min the minimum of all metrics collected that
    #   were aggregated into this data point (defaults to: 0)
    # @option options [Fixnum] :max the maximum of all metrics collected that
    #   were aggregated into this data point (defaults to: 0)
    # @option options [Fixnum] :std_dev the standard deviation of all metrics
    #   collected that were aggregated into this data point (defaults to: 0)
    # @option options [Hash] :properties the set of custom properties the client
    #   wants attached to this data item. (defaults to: {})
    # @option options [Hash] :measurements the set of custom measurements the
    #   client wants to attach to this data item (defaults to: {})
    def track_metric(name, value, options = {})
      data_point = Channel::Contracts::DataPoint.new(
        name: name || 'Null',
        value: value || 0,
        kind: options[:type] || Channel::Contracts::DataPointType::AGGREGATION,
        count: options[:count],
        min: options[:min],
        max: options[:max],
        std_dev: options[:std_dev]
      )

      data = Channel::Contracts::MetricData.new(
        metrics: [data_point],
        properties: options[:properties] || {}
      )

      channel.write(data, context)
    end

    # Sends a single trace statement.
    # @param [String] name the trace statement.
    # @param [Channel::Contracts::SeverityLevel] severity_level the severity level.
    # @param [Hash] options the options to create the
    #   {Channel::Contracts::EventData} object.
    # @option options [Hash] :properties the set of custom properties the client
    #   wants attached to this data item. (defaults to: {})
    def track_trace(name, severity_level = nil, options = {})
      data = Channel::Contracts::MessageData.new(
        message: name || 'Null',
        severity_level: severity_level || Channel::Contracts::SeverityLevel::INFORMATION,
        properties: options[:properties] || {}
      )

      channel.write(data, context)
    end

    # Sends a single request.
    # @param [String] id the unique identifier of the request.
    # @param (String) start_time the start time of the request.
    # @param [String] duration the duration to process the request.
    # @param [String] response_code the response code of the request.
    # @param [Boolean] success indicates whether the request succeeds or not.
    # @param [Hash] options the options to create the
    #   {Channel::Contracts::RequestData} object.
    # @option options [String] :name the name of the request.
    # @option options [String] :http_method the http method used for the request.
    # @option options [String] :url the url of the request.
    # @option options [Hash] :properties the set of custom properties the client
    #   wants attached to this data item. (defaults to: {})
    # @option options [Hash] :measurements the set of custom measurements the
    #   client wants to attach to this data item (defaults to: {})
    def track_request(id, start_time, duration, response_code, success, options = {})
      data = Channel::Contracts::RequestData.new(
        id: id || 'Null',
        duration: duration || '0:00:00:00.0000000',
        response_code: response_code || 200,
        success: success,
        name: options[:name],
        url: options[:url],
        properties: options[:properties] || {},
        measurements: options[:measurements] || {},
        # Must initialize http_method after properties because it's actually stored in properties
        http_method: options[:http_method]
      )

      channel.write(data, context, start_time)
    end

    # Sends a remote dependency
    # @param [String] id the unique identifier of the dependency.
    # @param [String] duration the duration to process the dependency.
    # @param [String] result_code the response code of the dependency.
    # @param [Boolean] success indicates whether the dependency succeeds or not.
    # @param [Hash] options the options to create the
    #   {Channel::Contracts::RemoteDependencyData} object.
    # @option options [String] :name the name of the dependency.
    # @option options [String] :data the data for the dependency.
    # @option options [String] :target the target for the dependency (i.e. its url).
    # @option options [String] :type the type of the dependency.
    # @option options [Hash] :properties the set of custom properties the client
    #   wants attached to this data item. (defaults to: {})
    # @option options [Hash] :measurements the set of custom measurements the
    #   client wants to attach to this data item (defaults to: {})
    def track_dependency(id, duration, result_code, success, options = {})
      data = Channel::Contracts::RemoteDependencyData.new(
        id: id || 'Null',
        duration: duration || '0:00:00:00.0000000',
        result_code: result_code || 200,
        success: success,
        name: options[:name],
        target: options[:target],
        data: options[:data],
        type: options[:type],
        properties: options[:properties] || {},
        measurements: options[:measurements] || {}
      )

      channel.write(data, context)
    end

    def flush(wait: false)
      channel.flush
      channel.queue.flush_notification.wait if wait
    end

    private

    attr_accessor :config, :channel
    attr_writer :context

    def configure_role_instance
      context.cloud.role_instance = config.insights_role_instance unless config.insights_role_instance.nil?
    end

    def configure_role_name
      context.cloud.role = config.insights_role_name unless config.insights_role_name.nil?
    end

    def configure_instrumentation_key
      context.instrumentation_key = config.insights_key
    end
  end
end
