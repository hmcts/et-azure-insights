# frozen_string_literal: true

RSpec.configure do |c|
  c.before do
    EtAzureInsights::RequestStack.clear
  end
end
