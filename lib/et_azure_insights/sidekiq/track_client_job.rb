# frozen_string_literal: true

module EtAzureInsights
  module Sidekiq
    # Sidekiq middleware to track sidekiq jobs on the client side.
    # This allows the request id to propogate (via the job data) to the sidekiq server
    # and also an event is sent to azure insights stating that a sidekiq job has been queued.
    class TrackClientJob
      def initialize(config: EtAzureInsights.config)
        self.config = config

        @sender = ApplicationInsights::Channel::AsynchronousSender.new
        @sender.send_interval = config.send_interval
        queue = ApplicationInsights::Channel::AsynchronousQueue.new @sender
        queue.max_queue_length = config.buffer_size
        @channel = ApplicationInsights::Channel::TelemetryChannel.new nil, queue

        self.client = ApplicationInsights::TelemetryClient.new config.insights_key, @channel
      end

      def call(_worker_class, job, _queue, _redis_pool)
        start = Time.now
        job['azure_insights_parent_request_id'] = EtAzureInsights::RequestStack.last unless EtAzureInsights::RequestStack.empty?
        begin
          retval = yield
        rescue Exception => e # rubocop:disable Lint/RescueException
          retval = e
        end

        client.track_event 'sidekiq_job_queued', properties: { jid: job['jid'], start_time: start.iso8601(7), success: !retval.is_a?(Exception) }
        track_and_raise_exception retval
      end

      private

      attr_accessor :config, :client

      def track_and_raise_exception(value)
        return value unless value.is_a?(Exception)

        client.track_exception value, handled_at: 'Unhandled'
        raise value
      end
    end
  end
end
