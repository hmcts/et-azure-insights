# frozen_string_literal: true

module EtAzureInsights
  module Sidekiq
    # Sidekiq middleware which works in conjunction with the EtAzureInsights::Sidekiq::TrackClientJob
    # to track request_ids to allow traceability from web server through to sidekiq and from sidekiq to sidekiq
    # This middleware will inform azure insights of the sidekiq job being processed.  It will appear as a 'request'
    # for now - as azure insights does not support background jobs or any form of external process yet.
    class TrackServerJob
      def initialize(config: EtAzureInsights.config, request_stack: EtAzureInsights::RequestStack, client_builder: ClientBuilder.new(config: config))
        self.config = config
        self.request_stack = request_stack
        self.client = client_builder.build
      end

      def call(_worker, job, _queue, &block)
        with_request_id job do
          assign_parent_request_id(job)
          start = Time.now
          retval = call_job_with_rescue(&block)
          stop = Time.now
          send_request(job, retval, start, stop)
          track_and_raise_exception retval
        end
      end

      private

      def with_request_id(job, &block)
        request_id = "sidekiq-#{job['jid']}"
        request_stack.for_request(request_id, &block)
      end

      def assign_parent_request_id(job)
        parent_request_id = job['azure_insights_parent_request_id']
        # @TODO Work out better interface to be able to customize context
        client.send(:context).operation.parent_id = parent_request_id unless parent_request_id.nil?
      end

      def send_request(job, retval, start, stop)
        start_time = start.iso8601(7)
        duration = format_request_duration(stop - start)

        is_success = !retval.is_a?(Exception)
        client.track_request request_stack.last,
                             start_time, duration,
                             is_success ? 200 : 500,
                             is_success,
                             name: job_name(job),
                             url: "sidekiq://#{job['jid']}/perform"
      end

      def call_job_with_rescue
        yield
      rescue Exception => e # rubocop:disable Lint/RescueException
        e
      end

      def track_and_raise_exception(value)
        return value unless value.is_a?(Exception)

        client.track_exception value, handled_at: 'Unhandled'
        raise value
      end

      attr_accessor :config, :client, :request_stack

      def format_request_duration(duration_seconds)
        if duration_seconds >= 86_400
          # just return 1 day when it takes more than 1 day which should not happen for requests.
          return '01.00:00:00.0000000'
        end

        Time.at(duration_seconds).gmtime.strftime('00.%H:%M:%S.%7N')
      end

      def job_name(job)
        if active_job?(job)
          args = job['args'].first['arguments'].to_json[0..100]
          "Active Job Worker for #{job['wrapped']} (#{args})"
        else
          args = job['args'].to_json[0..100]
          "Sidekiq worker #{job['class']} (#{args})"
        end
      end

      def active_job?(job)
        job['class'] =~ /\A(?:::)?ActiveJob/
      end
    end
  end
end
