# frozen_string_literal: true

require 'singleton'
module EtAzureInsights
  # Configuration instance for Et Azure Insights
  # Note that the configure and config methods are aliased in the top level EtAzureInsights module also for convenience
  # hence the code below shows this being used.
  #
  #  @example Configure your application using environment variables
  #    EtAzureInsights.configure do |c|
  #      insights_key = ENV.fetch('AZURE_APP_INSIGHTS_KEY', false)
  #      unless insights_key
  #        c.enable = false
  #        next
  #      end
  #      c.enable = true
  #      c.insights_key = insights_key
  #      c.insights_role_name = ENV.fetch('AZURE_APP_INSIGHTS_ROLE_NAME', 'et-api')
  #      c.insights_role_instance = ENV.fetch('HOSTNAME', nil)
  #      c.disabled_features << :excon # (An example of disabling an instrumentor if you
  #        have Excon installed but for some reason dont want it instrumented)
  #    end
  class Config
    include Singleton
    attr_accessor :enable, :insights_key, :insights_role_name, :insights_role_instance
    attr_accessor :buffer_size, :send_interval
    attr_accessor :disabled_features
    attr_accessor :disable_all_features
    attr_accessor :api_url

    # Yields and/or returns the single config instance to allow setting of values
    # @yield [EtAzureInsights::Config]
    # @return [EtAzureInsights::Config]
    def self.configure
      yield instance if block_given?
      instance
    end

    # returns the single config instance to allow reading of values
    # @return [EtAzureInsights::Config]
    def self.config
      instance
    end

    # @param [Symbol] name The feature name as defined in the feature detector
    # @return [Boolean] true if the instrumentor should be enabled
    def feature_enabled?(name)
      !disable_all_features && !disabled_features.include?(name)
    end

    private

    def initialize
      self.disabled_features = []
      self.api_url = 'https://dc.services.visualstudio.com/api'
    end
  end
end
