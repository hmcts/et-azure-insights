# frozen_string_literal: true

require 'rails_helper'
require 'et_azure_insights/trace_state'

RSpec.describe EtAzureInsights::TraceState do
  subject(:trace_state) { described_class }

  describe '.parse' do
    it 'should return a TraceState' do
      result = trace_state.parse('a=1, b=2, c=3')
      expect(result).to be_a(described_class)
    end

    it 'should return a TraceState convertible to a hash of key -> values' do
      result = trace_state.parse('a=abcdef, b=ghijkl, c=mnopqr').to_h
      expect(result).to eq 'a' => 'abcdef',
                           'b' => 'ghijkl',
                           'c' => 'mnopqr'
    end

    it 'should parse multi tenant values into nested hash' do
      result = trace_state.parse('a@vendor1=abcdef, b@vendor1=ghijkl, c@vendor2=mnopqr, d=stuvwxyz').to_h
      expect(result).to eq 'vendor1' => { 'a' => 'abcdef', 'b' => 'ghijkl' },
                           'vendor2' => { 'c' => 'mnopqr' },
                           'd' => 'stuvwxyz'
    end

    it 'should return nil if more than 32 key value pairs' do
      test_string = (1..33).inject([]) { |acc, v| acc.push("key#{v}=a") }.join(', ')
      result = trace_state.parse(test_string)

      expect(result).to be_nil
    end

    it 'returns nil if no equals sign' do
      result = trace_state.parse('a=abcdef, ghijkl, c=mnopqr')

      expect(result).to be_nil
    end

    it 'returns nil if key is > 256 chars' do
      result = trace_state.parse("a=abcdef, #{'b' * 257}=ghijkl, c=mnopqr")

      expect(result).to be_nil
    end

    it 'returns nil if key contains any uppercase characters' do
      result = trace_state.parse('a=1, B=2, c=3')

      expect(result).to be_nil
    end

    it 'returns nil if key contains a &' do
      result = trace_state.parse('a=1, b&=2, c=3')

      expect(result).to be_nil
    end

    it 'returns nil if key contains a .' do
      result = trace_state.parse('a=1, b.q=2, c=3')

      expect(result).to be_nil
    end

    it 'returns nil if key contains a :' do
      result = trace_state.parse('a=1, b:q=2, c=3')

      expect(result).to be_nil
    end

    it 'returns nil if key contains a ;' do
      result = trace_state.parse('a=1, b;q=2, c=3')

      expect(result).to be_nil
    end

    it 'returns nil if key contains a +' do
      result = trace_state.parse('a=1, b+q=2, c=3')

      expect(result).to be_nil
    end

    it 'returns nil if key begins with an underscore' do
      result = trace_state.parse('a=1, _b=2, c=3')

      expect(result).to be_nil
    end

    it 'returns nil if vendor part of key contains any uppercase characters' do
      result = trace_state.parse('a=1, b@Q=2, c=3')

      expect(result).to be_nil
    end

    it 'returns nil if the tenant id part of key contains any uppercase characters' do
      result = trace_state.parse('a=1, B@q=2, c=3')

      expect(result).to be_nil
    end

    it 'returns nil if duplicate keys' do
      result = trace_state.parse('a=1, a=2, c=3')

      expect(result).to be_nil
    end
  end
end
