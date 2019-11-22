# frozen_string_literal: true

require 'application_insights'
require 'et_azure_insights/feature_detector'
require 'et_azure_insights/engine'
require 'et_azure_insights/config'
require 'et_azure_insights/instrumentors'
require 'et_azure_insights/request_stack'
require 'et_azure_insights/client'
require 'et_azure_insights/client_builder'

# ET Azure Insights
#
# This gem is a general purpose rails integration for azure insights.
#
# At the moment (hence its name) it is only for use with the employment tribunals application
# but once this has been done it may become more generic and be usable for many apps including outside
# of HMCTS - but one step at a time.
module EtAzureInsights
  def self.config
    EtAzureInsights::Config.config
  end

  def self.configure(&block)
    EtAzureInsights::Config.configure(&block)
  end

  def self.global_insights_channel
    Thread.current[:azure_insights_global_channel] ||= begin
      sender = ApplicationInsights::Channel::AsynchronousSender.new
      sender.send_interval = config.send_interval
      queue = ApplicationInsights::Channel::AsynchronousQueue.new sender
      queue.max_queue_length = config.buffer_size
      ApplicationInsights::Channel::TelemetryChannel.new nil, queue
    end
  end
end
