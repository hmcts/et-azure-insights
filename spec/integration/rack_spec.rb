require 'spec_helper'
require 'net/http'
require 'rack'
require 'et_azure_insights'
require 'et_azure_insights/adapters/rack'
require 'et_azure_insights/adapters/net_http'
require 'random-port'
RSpec.describe 'Rack integration' do
  include_context 'with stubbed insights api'
  include_context 'insights call collector'
  context 'single service' do
    include_context 'rack servers' do
      rack_servers.register(:app1) do |env|
        [200, {}, ['OK from rack app 1 and rack app 2']]
      end
    end

    it 'informs insights of the request with positive status' do
      rack_servers.get_request(:app1, '/anything')

      expected = a_hash_including 'ver' => 1,
                                  'name' => 'Microsoft.ApplicationInsights.Request',
                                  'time' => instance_of(String),
                                  'sampleRate' => 100.0,
                                  'tags' => a_hash_including(
                                    'ai.internal.sdkVersion' => "rb:#{ApplicationInsights::VERSION}",
                                    'ai.cloud.role' => 'fakerolename',
                                    'ai.cloud.roleInstance' => 'fakeroleinstance',
                                    'ai.operation.id' => match(/\A|[0-9a-f]{32}\./)
                                  ),
                                  'data' => a_hash_including(
                                    'baseType' => 'RequestData',
                                    'baseData' => a_hash_including(
                                      'ver' => 2,
                                      'id' => match(/\A|[0-9a-f]{32}\./),
                                      'duration' => instance_of(String),
                                      'responseCode' => '200',
                                      'success' => true,
                                      'url' => "#{rack_servers.base_url_for(:app1)}/anything",
                                      'name' => 'GET /anything',
                                      'properties' => a_hash_including(
                                        'httpMethod' => 'GET'
                                      )
                                    )
                                  )
      expect { insights_call_collector.flatten }.to eventually(include expected).pause_for(0.05).within(0.5)
    end
  end

  context 'single service with 500 response' do
    include_context 'rack servers' do
      rack_servers.register(:app1) do |env|
        [500, {}, ['Internal Server Error']]
      end
    end

    it 'informs insights of the request with positive status' do
      rack_servers.get_request(:app1, '/anything')

      expected = a_hash_including 'ver' => 1,
                                  'name' => 'Microsoft.ApplicationInsights.Request',
                                  'time' => instance_of(String),
                                  'sampleRate' => 100.0,
                                  'tags' => a_hash_including(
                                    'ai.internal.sdkVersion' => "rb:#{ApplicationInsights::VERSION}",
                                    'ai.cloud.role' => 'fakerolename',
                                    'ai.cloud.roleInstance' => 'fakeroleinstance',
                                    'ai.operation.id' => match(/\A|[0-9a-f]{32}\./)
                                  ),
                                  'data' => a_hash_including(
                                    'baseType' => 'RequestData',
                                    'baseData' => a_hash_including(
                                      'ver' => 2,
                                      'id' => match(/\A|[0-9a-f]{32}\./),
                                      'duration' => instance_of(String),
                                      'responseCode' => '500',
                                      'success' => false,
                                      'url' => "#{rack_servers.base_url_for(:app1)}/anything",
                                      'name' => 'GET /anything',
                                      'properties' => a_hash_including(
                                        'httpMethod' => 'GET'
                                      )
                                    )
                                  )
      expect { insights_call_collector.flatten }.to eventually(include expected).pause_for(0.05).within(0.5)
    end
  end

  context 'single service with exception raised' do
    include_context 'rack servers' do
      rack_servers.register(:app1) do |env|
        raise 'Boom'
      end
    end

    it 'informs insights of the request with positive status' do
      rack_servers.get_request(:app1, '/anything') rescue nil

      expected = a_hash_including 'ver' => 1,
                                  'name' => 'Microsoft.ApplicationInsights.Request',
                                  'time' => instance_of(String),
                                  'sampleRate' => 100.0,
                                  'tags' => a_hash_including(
                                    'ai.internal.sdkVersion' => "rb:#{ApplicationInsights::VERSION}",
                                    'ai.cloud.role' => 'fakerolename',
                                    'ai.cloud.roleInstance' => 'fakeroleinstance',
                                    'ai.operation.id' => match(/\A|[0-9a-f]{32}\./)
                                  ),
                                  'data' => a_hash_including(
                                    'baseType' => 'RequestData',
                                    'baseData' => a_hash_including(
                                      'ver' => 2,
                                      'id' => match(/\A|[0-9a-f]{32}\./),
                                      'duration' => instance_of(String),
                                      'responseCode' => '500',
                                      'success' => false,
                                      'url' => "#{rack_servers.base_url_for(:app1)}/anything",
                                      'name' => 'GET /anything',
                                      'properties' => a_hash_including(
                                        'httpMethod' => 'GET'
                                      )
                                    )
                                  )
      expect { insights_call_collector.flatten }.to eventually(include expected).pause_for(0.05).within(0.5)
    end

    it 'informs insights of the exception' do
      rack_servers.get_request(:app1, '/anything')

      expected = a_hash_including 'ver' => 1,
                                  'name' => 'Microsoft.ApplicationInsights.Exception',
                                  'time' => instance_of(String),
                                  'sampleRate' => 100.0,
                                  'tags' => a_hash_including(
                                    'ai.internal.sdkVersion' => "rb:#{ApplicationInsights::VERSION}",
                                    'ai.cloud.role' => 'fakerolename',
                                    'ai.cloud.roleInstance' => 'fakeroleinstance',
                                    'ai.operation.id' => match(/\A|[0-9a-f]{32}\./)
                                  ),
                                  'data' => a_hash_including(
                                    'baseType' => 'ExceptionData',
                                    'baseData' => a_hash_including(
                                      'ver' => 2,
                                      'exceptions' => a_collection_including(
                                        a_hash_including 'id' => instance_of(Integer),
                                                         'outerId' => instance_of(Integer),
                                                         'typeName' => 'RuntimeError',
                                                         'message' => 'Boom',
                                                         'hasFullStack' => true,
                                                         'stack' => a_string_matching(/rack_spec\.rb/),
                                                         'parsedStack' => a_collection_including(
                                                           a_hash_including(
                                                             'fileName' => __FILE__
                                                           )
                                                         )
                                      ),
                                      'properties' => a_hash_including(
                                        'handledAt' => instance_of(String)
                                      )
                                    )
                                  )
      expect { insights_call_collector.flatten }.to eventually(include expected).pause_for(0.05).within(0.5)
    end
  end
end