# frozen_string_literal: true

module EtAzureInsights
  # A per thread stack used to record 'requests'.  A request is simply a request for work - either HTTP, sidekiq etc.
  # This stack is used to set the parent request id in azure insights to allow the linking of data.
  module RequestStack
    def self.push(value)
      stack.push(value)
    end

    def self.pop
      stack.pop
    end

    def self.for_request(value)
      push(value)
      yield.tap do
        pop
      end
    end

    def self.last
      stack.last
    end

    def self.empty?
      stack.empty?
    end

    def self.clear
      stack.clear
    end

    def self.stack
      Thread.current[:azure_insights_request_stack] ||= []
    end

    private_class_method :stack
  end
end
