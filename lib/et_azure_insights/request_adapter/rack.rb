# frozen_string_literal: true

require 'rack/request'
require 'forwardable'
require 'et_azure_insights/trace_parent'
module EtAzureInsights
  module RequestAdapter
    # A request adapter provides a normalised view of a request no matter where it came from
    # The norm is a rack request for a web server, which is what this class provides
    class Rack
      extend Forwardable

      # Creates a new instance from a rack environment
      # @param [Hash] env The rack environment
      # @return [EtAzureInsights::RequestAdapter::Rack]
      def self.from_env(env, trace_parent: ::EtAzureInsights::TraceParent)
        new(::Rack::Request.new(env), trace_parent: trace_parent)
      end

      # A new instance given a rack request
      # @param [Rack::Request] request The rack request
      def initialize(request, trace_parent: ::EtAzureInsights::TraceParent)
        self.request = request
        self.trace_parent = trace_parent
      end

      def name
        @name ||= "#{request_method.to_s.upcase} #{path}"
      end

      def request_method
        @request_method ||= request.request_method.downcase.to_sym
      end

      def trace_id
        parsed_traceparent&.trace_id
      end

      def span_id
        parsed_traceparent&.span_id
      end

      def trace_info?
        !parsed_traceparent.nil?
      end

      def request_id
        return SecureRandom.hex(16) unless request.env.key?('action_dispatch.request_id')

        request.env['action_dispatch.request_id'].gsub('-', '')
      end

      def_delegators :request, :url, :path, :has_header?, :fetch_header, :get_header

      private

      attr_accessor :request, :trace_parent

      def parsed_traceparent
        return @parsed_traceparent if defined?(@parsed_traceparent)

        @parsed_traceparent = parse_traceparent
      end

      def parse_traceparent
        return unless has_header?('HTTP_TRACEPARENT')

        header_value = fetch_header('HTTP_TRACEPARENT')
        trace_parent.parse(header_value)
      end
    end
  end
end
