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
      self.client = Client.new(config: config)
      yield client if block_given?
      client
    end

    private

    attr_accessor :client, :config
  end
end
