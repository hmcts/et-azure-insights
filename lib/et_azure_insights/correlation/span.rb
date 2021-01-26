# frozen_string_literal: true

require 'et_azure_insights/correlation/exceptions'
module EtAzureInsights
  module Correlation
    # A correlation span - used throughout the system to capture
    # nested spans.  This may be being removed - it might be over complex
    # but we will see !!
    class Span
      attr_reader :name, :parent, :id

      def self.current
        Thread.current[:et_azure_insights_correlation_current_span] ||= RootSpan.new
      end

      def self.reset_current
        Thread.current[:et_azure_insights_correlation_current_span] = RootSpan.new
      end

      def initialize(name:, parent: nil, id: nil, logger: EtAzureInsights.logger)
        self.name = name
        self.parent = parent
        self.id = id
        self.logger = logger
      end

      def open(name:, id: nil, &block)
        child_span = Span.new(name: name, parent: self, id: id)
        Thread.current[:et_azure_insights_correlation_current_span] = child_span
        if block_given?
          yield_and_close_span(child_span, &block)
        else
          child_span
        end
      end

      def close
        until Span.current.equal?(self)
          logger.warn "The span '#{name}' was stopped from being closed by the span '#{Span.current.name}' - force closing that first"
          Span.current.close
        end

        Thread.current[:et_azure_insights_correlation_current_span] = parent
      end

      def root?
        false
      end

      def path
        parent.path + [id]
      end

      private

      def yield_and_close_span(span)
        yield(span)
      ensure
        span.close
      end

      attr_accessor :logger
      attr_writer :name, :parent, :id
    end
  end
end
