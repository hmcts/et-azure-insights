# frozen_string_literal: true

require 'securerandom'
module EtAzureInsights
  # Parses a 'Traceparent Header' as defined in https://www.w3.org/TR/trace-context
  class TraceParent
    DEFAULT_VERSION = '00'
    DEFAULT_TRACE_FLAG = '01'
    attr_reader :version, :trace_id, :span_id, :trace_flag

    def self.parse(str)
      new(str)
    end

    # Produces a traceparent from a span - only uses the first and last ids - representing
    # the operation and the last span
    def self.from_span(span)
      path = span.path
      if path.length > 1
        new("#{DEFAULT_VERSION}-#{path.first}-#{path.last}-#{DEFAULT_TRACE_FLAG}")
      else
        new("#{DEFAULT_VERSION}-#{path.first}--#{DEFAULT_TRACE_FLAG}")
      end
    end

    def to_s
      [version, trace_id, span_id, trace_flag].join('-')
    end

    private

    def invalidate_trace_id!
      self.trace_id = SecureRandom.hex(16)
    end

    def invalidate_span_id!
      self.span_id = SecureRandom.hex(8)
    end

    def initialize(str)
      self.version = DEFAULT_VERSION
      invalidate_trace_id!
      invalidate_span_id!
      self.trace_flag = DEFAULT_TRACE_FLAG
      parse!(str)
    end

    def parse!(str)
      return if str.split(',').length > 1

      parts = str.split('-')
      self.version, self.trace_id, self.span_id, self.trace_flag = parts
      validate_all(parts)
    end

    def validate_all(parts)
      validate_parts(parts)
      validate_version_is_hex
      validate_version_not_ff
      validate_version
      validate_trace_flag
      validate_trace_id
      validate_span_id
    end

    def validate_parts(parts)
      if parts.length < 4
        invalidate_trace_id!
        invalidate_span_id!
        self.trace_flag ||= DEFAULT_TRACE_FLAG
        self.version ||= DEFAULT_VERSION
      elsif parts.length > 4
        invalidate_trace_id!
        invalidate_span_id!
      end
    end

    def validate_version_is_hex
      return if version =~ /\A[0-9a-f]{2}\z/

      self.version = DEFAULT_VERSION
      invalidate_trace_id!
    end

    def validate_version_not_ff
      return unless version == 'ff'

      self.version = DEFAULT_VERSION
      invalidate_trace_id!
      invalidate_span_id!
    end

    def validate_version
      return if version.match(/\A0[0-9a-f]\z/)

      self.version = DEFAULT_VERSION
    end

    def validate_trace_flag
      return if trace_flag.match(/\A[0-9a-f]{2}\z/)

      self.trace_flag = DEFAULT_TRACE_FLAG
      invalidate_trace_id!
    end

    def validate_trace_id
      return if trace_id.match(/\A[0-9a-f]{32}\z/) && trace_id != ('0' * 32)

      invalidate_trace_id!
    end

    def validate_span_id
      return if span_id.match(/\A[0-9a-f]{16}\z/) && span_id != ('0' * 16)

      invalidate_trace_id!
      invalidate_span_id!
    end

    attr_writer :version, :trace_id, :span_id, :trace_flag
  end
end
