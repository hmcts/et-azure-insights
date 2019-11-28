require 'et_azure_insights/trace_parent'
module EtAzureInsights
  # Used to track ids through the chain of http calls, sidekiq calls etc...
  # a central system for all to use
  class CorrelationIdManager
    def get_root_id(value)
      value.gsub(/\A\|/, '').gsub(/\..*\z/, '')
    end
  end
end