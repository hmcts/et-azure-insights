# frozen_string_literal: true

module EtAzureInsights
  module Correlation
    class SpanNotCurrentError < StandardError
    end
    class CannotCloseRootSpan < StandardError
    end
  end
end
