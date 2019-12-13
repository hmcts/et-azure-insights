# frozen_string_literal: true

require 'et_azure_insights/correlation/span'
module EtAzureInsights
  module Correlation
    # A special root span where all spans start from
    class RootSpan < Span
      attr_reader :name, :parent, :id

      def initialize
        self.name = 'Root Span'
        self.parent = nil
        self.id = nil
      end

      def close
        raise CannotCloseRootSpan, 'Cannot close the root span'
      end

      def root?
        true
      end

      def path
        []
      end
    end
  end
end