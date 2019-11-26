# frozen_string_literal: true

module EtAzureInsights
  module Adapters
    # An adapter to hook into and process typhoeus requests / responses and send
    # them on as a dependency to insights
    class ActiveRecord
      def self.setup(notifications: ::ActiveSupport::Notifications, config: EtAzureInsights.config, client: ClientBuilder.new(config: config).build, request_stack: EtAzureInsights::RequestStack)
        notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
          duration = finish - start
          instance.call(payload, duration)
        end
      end

      def self.instance
        Thread.current[:azure_insights_active_record_adapter] ||= new
      end

      def call(payload, duration)
        return if payload[:cache]
        send_to_client(payload, duration)
      end

      def initialize(config: EtAzureInsights.config, client: ClientBuilder.new(config: config).build, request_stack: EtAzureInsights::RequestStack)
        self.config = config
        self.client = client
        self.request_stack = request_stack
      end

      private

      attr_accessor :config, :client, :request_stack

      def send_to_client(payload, duration)
        with_request_id do
          request_id = request_stack.last
          client.track_dependency request_id,
                                  format_request_duration(duration),
                                  '200',
                                  true,
                                  target: target_from(payload),
                                  name: payload[:sql],
                                  type: type_from(payload),
                                  data: payload[:sql]
        end
      end

      def type_from(payload)
        payload[:connection].adapter_name
      end

      def target_from(payload)
        # @TODO This is not ideal, but is all we've got for now.  Need to find a more supported way of getting this information
        # it will probably be different for different database types as well
        low_level_connection = payload[:connection].instance_variable_get(:@connection)
        "#{low_level_connection.host}:#{low_level_connection.port}"
      end

      def format_request_duration(duration_seconds)
        if duration_seconds >= 86_400
          # just return 1 day when it takes more than 1 day which should not happen for requests.
          return '01.00:00:00.0000000'
        end

        Time.at(duration_seconds).gmtime.strftime('00.%H:%M:%S.%7N')
      end

      def with_request_id(&block)
        request_id = "active_record-#{SecureRandom.uuid}"
        request_stack.for_request(request_id, &block)
      end
    end
  end
end
