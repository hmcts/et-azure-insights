# frozen_string_literal: true

require 'spec_helper'
require 'et_azure_insights/config'
require 'et_azure_insights/client'
require 'et_azure_insights'
RSpec.describe EtAzureInsights::Client do
  include_context 'with stubbed insights api'
  let(:fake_config_attrs) do
    {
      enable: true,
      insights_key: fake_insights_key,
      insights_role_name: 'fakerolename',
      insights_role_instance: 'fakeroleinstance',
      buffer_size: 100,
      send_interval: 5.0,
      api_url: 'https://dc.services.visualstudio.com/api'
    }
  end
  let(:fake_config) { double(EtAzureInsights::Config, fake_config_attrs) }
  let(:insights_client_class) { class_spy(ApplicationInsights::TelemetryClient, new: insights_client) }
  let(:insights_client) { instance_spy(ApplicationInsights::TelemetryClient) }
  let(:insights_global_channel) { EtAzureInsights.global_insights_channel }
  subject(:client) { described_class.new(config: fake_config) }
  include_context 'insights call collector'

  describe '.new' do
    it 'returns a new instance' do
      expect(described_class.new(config: fake_config)).to be_a(described_class)
    end
  end

  describe '#track_page_view' do
    it 'sends the correct json' do
      client.track_page_view 'test', 'http://tempuri.org'
      client.flush
      expected = a_hash_including('ver' => 1, 'name' => 'Microsoft.ApplicationInsights.PageView',
                                  'time' => instance_of(String), 'sampleRate' => 100.0,
                                  'tags' => a_hash_including(
                                    'ai.internal.sdkVersion' => "rb:#{ApplicationInsights::VERSION}",
                                    'ai.cloud.role' => 'fakerolename',
                                    'ai.cloud.roleInstance' => 'fakeroleinstance'
                                  ),
                                  'data' => a_hash_including(
                                    'baseType' => 'PageViewData',
                                    'baseData' => a_hash_including(
                                      'ver' => 2, 'url' => 'http://tempuri.org', 'name' => 'test'
                                    )
                                  ))
      expect { insights_call_collector.flatten }.to eventually(include expected).pause_for(0.05).within(0.5)
    end
  end

  describe '#track_exception' do
    it 'sends the correct json' do
      begin
        raise ArgumentError, 'Some error'
      rescue StandardError => e
        client.track_exception e
      end
      client.flush

      expected = a_hash_including 'ver' => 1,
                                  'name' => 'Microsoft.ApplicationInsights.Exception',
                                  'time' => instance_of(String),
                                  'sampleRate' => 100.0,
                                  'tags' => a_hash_including(
                                    'ai.internal.sdkVersion' => "rb:#{ApplicationInsights::VERSION}",
                                    'ai.cloud.role' => 'fakerolename',
                                    'ai.cloud.roleInstance' => 'fakeroleinstance'
                                  ),
                                  'data' => a_hash_including(
                                    'baseType' => 'ExceptionData',
                                    'baseData' => a_hash_including(
                                      'ver' => 2,
                                      'exceptions' => [
                                        a_hash_including(
                                          'id' => 1, 'outerId' => 0, 'typeName' => 'ArgumentError',
                                          'message' => 'Some error', 'hasFullStack' => true, 'stack' => instance_of(String)
                                        )
                                      ],
                                      'properties' => { 'handledAt' => 'UserCode' }
                                    )
                                  )
      expect { insights_call_collector.flatten }.to eventually(include expected).pause_for(0.05).within(0.5)
    end
  end

  describe '#track_event' do
    it 'sends the correct json' do
      client.track_event 'test'
      client.flush
      expected = a_hash_including 'ver' => 1,
                                  'name' => 'Microsoft.ApplicationInsights.Event',
                                  'time' => an_instance_of(String),
                                  'sampleRate' => 100.0,
                                  'tags' => a_hash_including(
                                    'ai.internal.sdkVersion' => "rb:#{ApplicationInsights::VERSION}",
                                    'ai.cloud.role' => 'fakerolename',
                                    'ai.cloud.roleInstance' => 'fakeroleinstance'
                                  ),
                                  'data' => a_hash_including(
                                    'baseType' => 'EventData',
                                    'baseData' => a_hash_including('ver' => 2, 'name' => 'test')
                                  )
      expect { insights_call_collector.flatten }.to eventually(include expected).pause_for(0.05).within(0.5)
    end
  end

  describe '#track_metric' do
    it 'sends the correct json' do
      client.track_metric 'test', 42
      client.flush
      expected = a_hash_including 'ver' => 1,
                                  'name' => 'Microsoft.ApplicationInsights.Metric',
                                  'time' => instance_of(String),
                                  'sampleRate' => 100.0,
                                  'tags' => a_hash_including(
                                    'ai.internal.sdkVersion' => "rb:#{ApplicationInsights::VERSION}",
                                    'ai.cloud.role' => 'fakerolename',
                                    'ai.cloud.roleInstance' => 'fakeroleinstance'
                                  ),
                                  'data' => a_hash_including(
                                    'baseType' => 'MetricData',
                                    'baseData' => a_hash_including(
                                      'ver' => 2,
                                      'metrics' => [{ 'name' => 'test', 'kind' => 1, 'value' => 42 }]
                                    )
                                  )
      expect { insights_call_collector.flatten }.to eventually(include expected).pause_for(0.05).within(0.5)
    end
  end

  describe '#track_trace' do
    it 'sends the correct json' do
      client.track_trace 'test', ApplicationInsights::Channel::Contracts::SeverityLevel::WARNING
      client.flush
      expected = a_hash_including 'ver' => 1,
                                  'name' => 'Microsoft.ApplicationInsights.Message',
                                  'time' => instance_of(String),
                                  'sampleRate' => 100.0,
                                  'tags' => a_hash_including(
                                    'ai.internal.sdkVersion' => "rb:#{ApplicationInsights::VERSION}",
                                    'ai.cloud.role' => 'fakerolename',
                                    'ai.cloud.roleInstance' => 'fakeroleinstance'
                                  ),
                                  'data' => a_hash_including(
                                    'baseType' => 'MessageData',
                                    'baseData' => a_hash_including(
                                      'ver' => 2,
                                      'message' => 'test',
                                      'severityLevel' => 2
                                    )
                                  )
      expect { insights_call_collector.flatten }.to eventually(include expected).pause_for(0.05).within(0.5)
    end
  end

  describe '#track_request' do
    it 'sends the correct json' do
      start_time = Time.now.iso8601
      client.track_request 'test', start_time, '0:00:00:02.0000000', '200', true
      client.flush
      expected = a_hash_including 'ver' => 1,
                                  'name' => 'Microsoft.ApplicationInsights.Request',
                                  'time' => start_time,
                                  'sampleRate' => 100.0,
                                  'tags' => a_hash_including(
                                    'ai.internal.sdkVersion' => "rb:#{ApplicationInsights::VERSION}",
                                    'ai.cloud.role' => 'fakerolename',
                                    'ai.cloud.roleInstance' => 'fakeroleinstance'
                                  ),
                                  'data' => a_hash_including(
                                    'baseType' => 'RequestData',
                                    'baseData' => a_hash_including(
                                      'ver' => 2,
                                      'id' => 'test',
                                      'duration' => '0:00:00:02.0000000',
                                      'responseCode' => '200',
                                      'success' => true
                                    )
                                  )
      expect { insights_call_collector.flatten }.to eventually(include expected).pause_for(0.05).within(0.5)
    end
  end

  describe '#track_dependency' do
    it 'sends the correct json' do
      client.track_dependency 'testid', '0:00:00:02.0000000', '200', true,
                              name: 'select customers proc',
                              data: 'SELECT * FROM Customers',
                              target: 'http://dbname',
                              type: 'ZSQL'

      expected = a_hash_including 'ver' => 1,
                                  'name' => 'Microsoft.ApplicationInsights.RemoteDependency',
                                  'time' => instance_of(String),
                                  'sampleRate' => 100.0,
                                  'tags' => a_hash_including(
                                    'ai.internal.sdkVersion' => "rb:#{ApplicationInsights::VERSION}",
                                    'ai.cloud.role' => 'fakerolename',
                                    'ai.cloud.roleInstance' => 'fakeroleinstance'
                                  ),
                                  'data' => a_hash_including(
                                    'baseType' => 'RemoteDependencyData',
                                    'baseData' => a_hash_including(
                                      'ver' => 2,
                                      'name' => 'select customers proc',
                                      'id' => 'testid',
                                      'resultCode' => '200',
                                      'duration' => '0:00:00:02.0000000',
                                      'success' => true,
                                      'data' => 'SELECT * FROM Customers'
                                    )
                                  )
      expect { insights_call_collector.flatten }.to eventually(include expected).pause_for(0.05).within(0.5)
    end
  end
end
