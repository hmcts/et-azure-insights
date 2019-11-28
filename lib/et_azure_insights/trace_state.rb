# frozen_string_literal: true

module EtAzureInsights
  # Parses a 'Tracestate Header' as defined in https://www.w3.org/TR/trace-context
  class TraceState
    def self.parse(str)
      instance = new(str)
      instance.valid? ? instance : nil
    end

    def valid?
      valid
    end

    def to_h
      hash
    end

    private

    attr_accessor :valid, :parts, :hash

    def initialize(str)
      self.valid = false
      parse!(str)
    end

    def parse!(str)
      self.parts = str.split(',').map(&:strip)
      return if parts.length > 32

      parse_into_hash

      self.valid = !hash.nil?
    end

    def parse_into_hash
      self.hash = catch(:parsing_error) do
        parts.each_with_object({}) do |part, acc|
          key, value = part.split('=')
          next acc if key.nil? && value.nil?

          throw(:parsing_error, nil) if value.nil?
          parse_key_value_pair(acc, key, value)
        end
      end
    end

    def parse_key_value_pair(acc, key, value)
      if multi_tenant_key?(key)
        parse_multi_tenant_key_value_pair(acc, key, value)
      else
        throw(:parsing_error, nil) unless valid_key?(key)
        throw(:parsing_error, nil) if acc.key?(key)

        acc[key] = value
      end
    end

    def parse_multi_tenant_key_value_pair(acc, key, value)
      tenant, vendor = split_multi_tenant_key(key)
      throw(:parsing_error, nil) unless valid_tenant?(tenant)
      throw(:parsing_error, nil) unless valid_vendor?(vendor)

      acc[vendor] ||= {}
      throw(:parsing_error, nil) if acc[vendor].key?(tenant)

      acc[vendor][tenant] = value
    end

    def valid_tenant?(tenant)
      tenant.match(/\A[^_]/) && tenant.match(%r{\A[\ ]?[a-z0-9\*\-\_/]{1,241}\z})
    end

    def valid_vendor?(vendor)
      vendor.match(/\A[^_]/) && vendor.match(%r{\A[\ ]?[a-z0-9\*\-\_/]{1,14}\z})
    end

    def valid_key?(key)
      key.match(/\A[^_]/) && key.match(%r{\A[\ ]?[a-z0-9\*\-\_/]{1,256}\z})
    end

    def multi_tenant_key?(key)
      key.include?('@')
    end

    def split_multi_tenant_key(key)
      key.split('@').map(&:strip)
    end
  end
end
