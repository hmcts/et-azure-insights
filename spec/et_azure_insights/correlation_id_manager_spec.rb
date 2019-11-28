require 'rails_helper'
require 'et_azure_insights/correlation_id_manager'
RSpec.describe EtAzureInsights::CorrelationIdManager do
  subject(:manager) { described_class.new }
  describe '#get_root_id' do
    it 'returns the whole string if not beginning with pipe or containing .' do
      expect(manager.get_root_id('test_value')).to eq 'test_value'
    end

    it 'returns the whole string if the string does not begin with but contains pipe and does not contain .' do
      expect(manager.get_root_id('tes|t_value')).to eq 'tes|t_value'
    end

    it 'returns the string to the right of the | if the string begins with pipe but does not contain .' do
      expect(manager.get_root_id('|test_value')).to eq 'test_value'
    end

    it 'returns the string to the right of the | up to but not including the first .' do
      expect(manager.get_root_id('|test_value.something_else')).to eq 'test_value'
    end
  end
end