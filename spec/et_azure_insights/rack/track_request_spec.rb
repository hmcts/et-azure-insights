# frozen_string_literal: true

require 'rails_helper'
require 'zlib'
RSpec.describe EtAzureInsights::Rack::TrackRequest do
  let(:example_config) do
    instance_double EtAzureInsights::Config,
                    enable: true,
                    insights_key: 'myinsightskey',
                    insights_role_name: 'myinsightsrolename',
                    insights_role_instance: 'myinsightsroleinstance',
                    buffer_size: 1,
                    send_interval: 0.1
  end
  let(:subject) { described_class.new(example_app, config: example_config) }
  let(:example_env) do
    {}
  end
  let(:example_app) { proc { [200, {}, 'Hello World'] } }
  let(:call_collector) { [] }
  before do
    calls = call_collector
    responder = lambda { |request|
      data = Zlib.gunzip(request.body)
      calls << JSON.parse(data)
      { body: '', status: 200, headers: {} }
    }
    stub_request(:post, 'https://dc.services.visualstudio.com/v2/track')
      .to_return(responder)
  end

  it 'sets the request id in the env' do
    subject.call(example_env)
    expect(example_env).to include 'ApplicationInsights.request.id' => instance_of(String)
  end

  context 'with tracking app' do
    stack_bottom_during = nil
    let(:example_app) do
      proc do
        stack_bottom_during = EtAzureInsights::RequestStack.last
        [200, {}, 'Hello World']
      end
    end
    it 'executes the app with the request_id on the stack and finishes without it' do
      subject.call(example_env)
      expect(stack_bottom_during).to eq example_env['ApplicationInsights.request.id']
      expect(EtAzureInsights::RequestStack.last).to be nil
    end
  end

  it 'sets the role in the data' do
    subject.call(example_env)
    raise 'NotYetFinished  - to validate the data'

    # expect(subject.send(:client).channel.queue.pop).to have_attributes data: instance_of(Object)
  end
end
