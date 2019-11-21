# frozen_string_literal: true

module EtAzureInsights
  # A factory for creating a new client configured for the request that is required
  # to be made (i.e. with context set correctly)
  # Also provides a global 'channel' for use by all clients as each channel
  # spins up a thread for buffering the requests
  class ClientBuilder
    def initialize(config: EtAzureInsights.config)
      self.config = config
    end

    def build
      self.client = ApplicationInsights::TelemetryClient.new config.insights_key, channel
      configure_role_name
      configure_role_instance
      yield client if block_given?
      client
    end

    private

    attr_accessor :client, :config

    def channel
      Thread.current[:azure_insights_global_channel] ||= begin
        sender = ApplicationInsights::Channel::AsynchronousSender.new
        sender.send_interval = config.send_interval
        queue = ApplicationInsights::Channel::AsynchronousQueue.new sender
        queue.max_queue_length = config.buffer_size
        ApplicationInsights::Channel::TelemetryChannel.new nil, queue
      end
    end

    def configure_role_instance
      client.context.cloud.role_instance = config.insights_role_instance unless config.insights_role_instance.nil?
    end

    def configure_role_name
      client.context.cloud.role_name = config.insights_role_name unless config.insights_role_name.nil?
    end
  end
end
