RSpec.shared_context 'with stubbed insights api' do
  let(:fake_insights_app_id) { '5c9505f5-2624-411d-bbae-b23014653dec' }
  let(:fake_insights_key) { EtAzureInsights.config.insights_key }
  before do
    stub_request(:get, "https://dc.services.visualstudio.com/api/profiles/#{fake_insights_key}/appId")
      .to_return(status: 200, body: fake_insights_app_id, headers: { 'Content-Type' => 'text/plain' })
  end
end