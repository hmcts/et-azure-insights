# frozen_string_literal: true

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
  #    end
  class Config
    include Singleton
    attr_accessor :enable, :insights_key, :insights_role_name, :insights_role_instance

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
  end
end
