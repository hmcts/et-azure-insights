# frozen_string_literal: true

require 'rack/request'
require 'forwardable'
require 'et_azure_insights/trace_parent'
require 'sidekiq/api'
module EtAzureInsights
  module RequestAdapter
    # A request adapter provides a normalised view of a request no matter where it came from
    # This adapter normalises a sidekiq job
    class SidekiqJob

      # Creates a new instance from the sidekiq job hash
      # @param [Hash] job_hash The sidekiq job hash
      # @return [EtAzureInsights::RequestAdapter::SidekiqJob]
      def self.from_job_hash(job_hash, trace_parent: ::EtAzureInsights::TraceParent)
        new(job_record_class.new(job_hash), trace_parent: trace_parent)
      end

      def self.job_record_class
        ::Sidekiq.const_defined?('JobRecord') ? ::Sidekiq::JobRecord : ::Sidekiq::Job
      end

      # A new instance given a rack request
      # @param [Rack::Request] request The rack request
      def initialize(request, trace_parent: ::EtAzureInsights::TraceParent)
        self.request = request
        self.trace_parent = trace_parent
      end

      def url
        "sidekiq://#{request.queue}/#{request.klass.split('::').last}#{path}"
      end

      def path
        "/#{request.jid}"
      end

      def name
        @name ||= "#{request_method.to_s.upcase} /#{request.queue}/#{request.klass.split('::').last}#{path}"
      end

      def request_method
        @request_method = :perform
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
        SecureRandom.hex(16)
      end

      def fetch_header(key, &block)
        headers.fetch(key, &block)
      end

      def get_header(key)
        headers[key]
      end

      def has_header?(key)
        headers.key?(key)
      end


      private

      attr_accessor :request, :trace_parent

      def headers
        return @headers if defined?(@headers)
        @headers = request['azure_insights_headers']
        @headers ||= {}
      end

      def parsed_traceparent
        return @parsed_traceparent if defined?(@parsed_traceparent)

        @parsed_traceparent = parse_traceparent
      end

      def parse_traceparent
        return unless has_header?('traceparent')

        header_value = fetch_header('traceparent')
        trace_parent.parse(header_value)
      end
    end
  end
end
