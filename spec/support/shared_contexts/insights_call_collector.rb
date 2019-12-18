require 'zlib'
# This is over complex as I am moving from the original call collector to a fake insights server idea
# this is because it was getting too complex to search for things in the tests.
# Eventually, the insights call collector will go away
RSpec.shared_context 'insights call collector' do |*args, &block|
  class InsightsCallCollector < Array
    def request_data_named(name, timeout: 0.5, sleep: 0.1)
      wait_for(timeout: timeout, sleep: sleep) do
        flatten.detect { |r| r['data']['baseType'] == 'RequestData' && r.dig('data', 'baseData', 'name') == name }
      end
    end

    def remote_dependency_for_request(request, timeout: 0.5, sleep: 0.1)
      wait_for(timeout: timeout, sleep: sleep) do
        flatten.detect { |r| r['data']['baseType'] == 'RemoteDependencyData' && r.dig('tags', 'ai.operation.parentId') == request.dig('data', 'baseData', 'id') }
      end
    end

    def sidekiq_request_for_dependency(dependency, timeout: 0.5, sleep: 0.1)
      wait_for(timeout: timeout, sleep: sleep) do
        flatten.detect { |r| r['data']['baseType'] == 'RequestData' && r.dig('tags', 'ai.operation.parentId') == dependency.dig('data', 'baseData', 'id') && r['data']['baseData']['url'] =~/\Asidekiq:\/\// }
      end
    end

    def wait_for(timeout: 0.5, sleep: 0.1)
      Timeout.timeout timeout do
        loop do
          data = yield
          break data unless data.nil?

          sleep sleep
        end
      end
    end
  end
  let(:insights_call_collector) { InsightsCallCollector.new }

  def insights_flush
    EtAzureInsights::Client.client.flush(wait: true)
  end

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
  after do
    insights_flush
  end
end