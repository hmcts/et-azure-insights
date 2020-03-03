# frozen_string_literal: true

require 'rack/request'
require 'forwardable'
require 'et_azure_insights/trace_parent'
require 'sidekiq/api'
require_relative './sidekiq_job'
module EtAzureInsights
  module RequestAdapter
    # A request adapter provides a normalised view of a request no matter where it came from
    # This adapter normalises an active job job
    class ActiveJobJob < SidekiqJob

      # Creates a new instance from the active job hash
      # @param [Hash] job_hash The active job hash
      # @return [EtAzureInsights::RequestAdapter::ActiveJobJob]
      def self.from_job_hash(job_hash, trace_parent: ::EtAzureInsights::TraceParent)
        new(::Sidekiq::Job.new(job_hash), trace_parent: trace_parent)
      end

      def url
        "sidekiq://#{request.queue}/#{request.item['wrapped'].to_s.split('::').last}#{path}"
      end

      def name
        @name ||= "#{request_method.to_s.upcase} /#{request.queue}/#{request.item['wrapped'].to_s.split('::').last}#{path}"
      end
    end
  end
end
