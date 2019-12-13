require 'zlib'
RSpec.shared_context 'insights call collector' do |*args, &block|
  let(:insights_call_collector) { [] }
  before do
    calls = insights_call_collector
    responder = lambda { |request|
      data = Zlib.gunzip(request.body)
      calls << JSON.parse(data)
      { body: '', status: 200, headers: {} }
    }
    stub_request(:post, 'https://dc.services.visualstudio.com/v2/track')
      .to_return(responder)
  end
end