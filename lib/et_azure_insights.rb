# frozen_string_literal: true

require 'et_azure_insights/engine'
require 'et_azure_insights/config'
require 'et_azure_insights/rack'

# ET Azure Insights
#
# This gem is a general purpose rails integration for azure insights.
#
# At the moment (hence its name) it is only for use with the employment tribunals application
# but once this has been done it may become more generic and be usable for many apps including outside
# of HMCTS - but one step at a time.
#
module EtAzureInsights
  def self.config
    EtAzureInsights::Config.config
  end

  def self.configure(&block)
    EtAzureInsights::Config.configure(&block)
  end
end
