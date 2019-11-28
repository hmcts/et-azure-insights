# frozen_string_literal: true

require 'rails_helper'
require 'et_azure_insights/trace_parent'
RSpec.describe EtAzureInsights::TraceParent do
  subject(:trace_parent) { described_class }

  describe '.parse' do
    it 'should return a TraceParent' do
      result = trace_parent.parse('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')
      expect(result).to be_a(described_class)
    end

    it 'should parse a valid traceparent into its component parts' do
      result = trace_parent.parse('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')
      expect(result).to have_attributes version: '00',
                                        trace_id: '4bf92f3577b34da6a3ce929d0e0e4736',
                                        span_id: '00f067aa0ba902b7',
                                        trace_flag: '01'
    end

    it 'sets trace_id and span_id to random values if more than 1 traceparent is present' do
      result = trace_parent.parse('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01,00-5bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')
      expect(result).to have_attributes version: '00',
                                        trace_id: satisfy { |v| v != '4bf92f3577b34da6a3ce929d0e0e4736' && v =~ /\A[0-9a-z]{32}\z/ },
                                        span_id: satisfy { |v| v != '00f067aa0ba902b7' && v =~ /\A[0-9a-z]{16}\z/ },
                                        trace_flag: '01'
    end

    it 'sets trace_id and span_id to random values if traceparent doesnt have enough values' do
      result = trace_parent.parse('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7')
      expect(result).to have_attributes version: '00',
                                        trace_id: satisfy { |v| v != '4bf92f3577b34da6a3ce929d0e0e4736' && v =~ /\A[0-9a-z]{32}\z/ },
                                        span_id: satisfy { |v| v != '00f067aa0ba902b7' && v =~ /\A[0-9a-z]{16}\z/ },
                                        trace_flag: '01'
    end

    it 'sets trace_id to random value and version to 00 if version is not valid lower case hex' do
      result = trace_parent.parse('0F-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')
      expect(result).to have_attributes version: '00',
                                        trace_id: satisfy { |v| v != '4bf92f3577b34da6a3ce929d0e0e4736' && v =~ /\A[0-9a-z]{32}\z/ },
                                        span_id: '00f067aa0ba902b7',
                                        trace_flag: '01'
    end

    it 'sets trace_id and span_id to random values if version is 00 and the number of parts in the traceparent is not 4' do
      result = trace_parent.parse('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01-99')
      expect(result).to have_attributes version: '00',
                                        trace_id: satisfy { |v| v != '4bf92f3577b34da6a3ce929d0e0e4736' && v =~ /\A[0-9a-z]{32}\z/ },
                                        span_id: satisfy { |v| v != '00f067aa0ba902b7' && v =~ /\A[0-9a-z]{16}\z/ },
                                        trace_flag: '01'
    end

    it 'sets version to 00, trace_id and span_id to random versions if the version is ff' do
      result = trace_parent.parse('ff-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')
      expect(result).to have_attributes version: '00',
                                        trace_id: satisfy { |v| v != '4bf92f3577b34da6a3ce929d0e0e4736' && v =~ /\A[0-9a-z]{32}\z/ },
                                        span_id: satisfy { |v| v != '00f067aa0ba902b7' && v =~ /\A[0-9a-z]{16}\z/ },
                                        trace_flag: '01'
    end

    it 'sets version to 00 if the version does not match /^0[0-9a-f]$/' do
      result = trace_parent.parse('1f-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')
      expect(result).to have_attributes version: '00',
                                        trace_id: '4bf92f3577b34da6a3ce929d0e0e4736',
                                        span_id: '00f067aa0ba902b7',
                                        trace_flag: '01'
    end

    it 'sets the trace_id to random value and the trace_flag to default if the trace_flag is not valid lowercase hex' do
      result = trace_parent.parse('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-FE')
      expect(result).to have_attributes version: '00',
                                        trace_id: satisfy { |v| v != '4bf92f3577b34da6a3ce929d0e0e4736' && v =~ /\A[0-9a-z]{32}\z/ },
                                        span_id: '00f067aa0ba902b7',
                                        trace_flag: '01'
    end

    it 'sets the trace_id to new random value if trace_id is 32 zeros' do
      result = trace_parent.parse('00-00000000000000000000000000000000-00f067aa0ba902b7-01')
      expect(result).to have_attributes version: '00',
                                        trace_id: satisfy { |v| v != '00000000000000000000000000000000' && v =~ /\A[0-9a-z]{32}\z/ },
                                        span_id: '00f067aa0ba902b7',
                                        trace_flag: '01'
    end

    it 'sets the trace_id to new random value if trace_id is >32 hex chars' do
      result = trace_parent.parse('00-4bf92f3577b34da6a3ce929d0e0e4736a-00f067aa0ba902b7-01')
      expect(result).to have_attributes version: '00',
                                        trace_id: satisfy { |v| v != '4bf92f3577b34da6a3ce929d0e0e4736a' && v =~ /\A[0-9a-z]{32}\z/ },
                                        span_id: '00f067aa0ba902b7',
                                        trace_flag: '01'
    end

    it 'sets the trace_id to new random value if trace_id is <32 hex chars' do
      result = trace_parent.parse('00-4bf92f3577b34da6a3ce929d0e0e473-00f067aa0ba902b7-01')
      expect(result).to have_attributes version: '00',
                                        trace_id: satisfy { |v| v != '4bf92f3577b34da6a3ce929d0e0e473' && v =~ /\A[0-9a-z]{32}\z/ },
                                        span_id: '00f067aa0ba902b7',
                                        trace_flag: '01'
    end

    it 'sets the trace_id to new random value if trace_id is 32 chars but 1 not hex' do
      result = trace_parent.parse('00-gbf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')
      expect(result).to have_attributes version: '00',
                                        trace_id: satisfy { |v| v != 'gbf92f3577b34da6a3ce929d0e0e4736' && v =~ /\A[0-9a-z]{32}\z/ },
                                        span_id: '00f067aa0ba902b7',
                                        trace_flag: '01'
    end

    it 'sets the span_id and trace_id to a random value if span_id is 16 zeros' do
      result = trace_parent.parse('00-4bf92f3577b34da6a3ce929d0e0e4736-0000000000000000-01')
      expect(result).to have_attributes version: '00',
                                        trace_id: satisfy { |v| v != '4bf92f3577b34da6a3ce929d0e0e4736' && v =~ /\A[0-9a-z]{32}\z/ },
                                        span_id: satisfy { |v| v != '0000000000000000' && v =~ /\A[0-9a-z]{16}\z/ },
                                        trace_flag: '01'
    end

    it 'sets the span_id and trace_id to a random value if span_id is < 16 hex digits' do
      result = trace_parent.parse('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b-01')
      expect(result).to have_attributes version: '00',
                                        trace_id: satisfy { |v| v != '4bf92f3577b34da6a3ce929d0e0e4736' && v =~ /\A[0-9a-z]{32}\z/ },
                                        span_id: satisfy { |v| v != '00f067aa0ba902b' && v =~ /\A[0-9a-z]{16}\z/ },
                                        trace_flag: '01'
    end

    it 'sets the span_id and trace_id to a random value if span_id is > 16 hex digits' do
      result = trace_parent.parse('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902bab-01')
      expect(result).to have_attributes version: '00',
                                        trace_id: satisfy { |v| v != '4bf92f3577b34da6a3ce929d0e0e4736' && v =~ /\A[0-9a-z]{32}\z/ },
                                        span_id: satisfy { |v| v != '00f067aa0ba902bab' && v =~ /\A[0-9a-z]{16}\z/ },
                                        trace_flag: '01'
    end

    it 'sets the span_id and trace_id to a random value if span_id is 16 chars but 1 is not hex' do
      result = trace_parent.parse('00-4bf92f3577b34da6a3ce929d0e0e4736-g0f067aa0ba902ba-01')
      expect(result).to have_attributes version: '00',
                                        trace_id: satisfy { |v| v != '4bf92f3577b34da6a3ce929d0e0e4736' && v =~ /\A[0-9a-z]{32}\z/ },
                                        span_id: satisfy { |v| v != 'g0f067aa0ba902ba' && v =~ /\A[0-9a-z]{16}\z/ },
                                        trace_flag: '01'
    end
  end
end
