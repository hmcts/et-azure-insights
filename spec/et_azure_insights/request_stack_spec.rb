# frozen_string_literal: true

require 'spec_helper'
RSpec.describe EtAzureInsights::RequestStack do
  subject(:stack) { described_class }
  describe '.for_request' do
    it 'yields with the new value at the bottom' do
      stack.push 'originalrequestid'
      results = []
      stack.for_request('newrequestid') do
        results << stack.last
      end
      results << stack.last
      expect(results).to eq %w[newrequestid originalrequestid]
    end
  end

  describe '.empty?' do
    it 'is true when empty' do
      expect(stack.empty?).to be true
    end

    it 'is false when not empty' do
      stack.push 'anything'
      expect(stack.empty?).to be false
    end
  end

  it 'has seperate stacks per thread' do
    stack.push 'originalrequestid'
    aggregate_failures 'validating all 3 stacks' do
      t1 = Thread.new do
        expect(stack.pop).to be nil
      end
      t2 = Thread.new do
        expect(stack.pop).to be nil
      end
      t1.join
      t2.join
      expect(stack.pop).to eq 'originalrequestid'
    end
  end
end
