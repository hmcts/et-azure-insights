require 'spec_helper'
require 'et_azure_insights'
require 'et_azure_insights/correlation/span'

RSpec.describe EtAzureInsights::Correlation::Span do
  subject(:span) { EtAzureInsights::Correlation::RootSpan.new }
  before { described_class.reset_current }

  describe '.current' do
    it 'starts off as the special root span' do
      result = described_class.current

      expect(result).to be_a(described_class).and(have_attributes root?: true)
    end
  end

  describe '#open' do
    it 'stores the name and id which are publically accessible' do
      span.open name: 'child span', id: '4bf92f3577b34da6a3ce929d0e0e4736' do |child|
        expect(child).to have_attributes name: 'child span',
                                         id: '4bf92f3577b34da6a3ce929d0e0e4736'
      end
    end

    it 'creates a new span traceable back to its parent' do
      span.open name: 'child span', id: '4bf92f3577b34da6a3ce929d0e0e4736' do |child|
        expect(child.parent).to be span
      end
    end

    it 'sets the current span to the child' do
      span.open(name: 'child span', id: '4bf92f3577b34da6a3ce929d0e0e4736') do |child|
        expect(described_class.current).to be child
      end
    end

    it 'yields the span to the block if provided' do
      open = -> test_block { span.open(name: 'child span', id: '4bf92f3577b34da6a3ce929d0e0e4736', &test_block) }

      expect(open).to yield_with_args(instance_of(described_class))
    end

    it 'closes the span if a block was provided' do
      # We must start from whatever is current (NullSpan) as creating a new instance does not change the current
      starting_span = described_class.current
      starting_span.open name: 'child span', id: '4bf92f3577b34da6a3ce929d0e0e4736' do
        'doesnt matter'
      end

      expect(described_class.current).to be(starting_span)
    end

    it 'returns the result of the block if provided' do
      example_output = "example output"
      result = span.open name: 'child span', id: '4bf92f3577b34da6a3ce929d0e0e4736' do
        example_output
      end

      expect(result).to be example_output
    end
  end

  describe '#close' do
    let(:parent_span) { described_class.new(name: 'parent span') }
    subject(:span) { parent_span.open(name: 'child span', id: '4bf92f3577b34da6a3ce929d0e0e4736') }

    it 'sets the current span to the parent' do
      span.close

      expect(described_class.current).to be parent_span
    ensure
      EtAzureInsights::Correlation::Span.reset_current
    end
  end

  describe 'path' do
    it 'is the correct array that can be joined easily' do
      span.open(name: 'grandparent span', id: '4bf92f3577b34da6a3ce929d0e0e4736') do |grandparent_span|
        grandparent_span.open(name: 'parent span', id: '00f067aa0ba902b7') do |parent_span|
          parent_span.open(name: 'child span', id: 'fff067aa0ba902b7') do |child_span|
            expect(child_span.path).to eql ['4bf92f3577b34da6a3ce929d0e0e4736', '00f067aa0ba902b7', 'fff067aa0ba902b7']
          end
        end
      end
    end
  end
end
