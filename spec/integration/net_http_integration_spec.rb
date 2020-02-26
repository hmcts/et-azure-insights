require 'spec_helper'
require 'net/http'
require 'rack'
require 'et_azure_insights'
require 'et_azure_insights/adapters/rack'
require 'et_azure_insights/adapters/net_http'
require 'random-port'
RSpec.describe 'Rack and net http integration' do
  include_context 'with stubbed insights api'
  around do |example|
    begin
      EtAzureInsights::Adapters::NetHttp.setup
      example.run
    ensure
      EtAzureInsights::Adapters::NetHttp.uninstall
    end
  end
  include_context 'insights call collector'

  context '2 service chain' do
    # Here, we will configure 2 rack applications
    # Our test suite calls the first rack app with the tracking disabled (as we are not testing this part)
    # The first rack app will call the second
    #
    include_context 'rack servers' do
      rack_servers.register(:app1) do |env|
        rack_servers.get_request(:app2, '', disable_tracking: false)
        [200, {}, ['OK from rack app 1 and rack app 2']]
      end
      rack_servers.register(:app2) do |env|
        [200, {}, ['OK from rack app 2']]
      end
    end

    it 'inform insights of the start of the chain' do
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

    it 'informs insights of the external dependency between app1 and app2' do
      rack_servers.get_request(:app1, '/anything')

      # @TODO This waits for a the request for the first service to be sent (as it wont get sent until the second has responded) - makes the rest easier knowing they are all there.  Needs a better way of doing it
      expect { insights_call_collector.flatten }.to eventually(include a_hash_including 'data' => a_hash_including('baseData' => a_hash_including('url' => "#{rack_servers.base_url_for(:app1)}/anything"))).pause_for(0.05).within(0.5)

      app1_request_record = insights_call_collector.flatten.detect { |r| r['data']['baseData']['url'] == "#{rack_servers.base_url_for(:app1)}/anything" }
      original_operation_id = app1_request_record.dig('tags', 'ai.operation.id')
      parent_id = app1_request_record.dig('data', 'baseData', 'id')
      dep_record = insights_call_collector.flatten.detect { |r| r['data']['baseType'] == 'RemoteDependencyData' }
      tags_expectation = a_hash_including(
        'ai.internal.sdkVersion' => "rb:#{ApplicationInsights::VERSION}",
        'ai.cloud.role' => 'fakerolename',
        'ai.cloud.roleInstance' => 'fakeroleinstance',
        'ai.operation.parentId' => parent_id,
        'ai.operation.id' => original_operation_id,
        'ai.operation.name' => 'GET /anything'
      )
      base_data_expectation = a_hash_including(
        'ver' => 2,
        'id' => match(/\A\|[0-9a-f]{32}\.[0-9a-f]{16}\.\z/),
        'resultCode' => '200',
        'duration' => instance_of(String),
        'success' => true,
        'name' => "GET #{rack_servers.base_url_for(:app2)}/",
        'data' => "GET #{rack_servers.base_url_for(:app2)}/",
        'target' => "localhost:#{rack_servers.port_for(:app2)}",
        'type' => 'Http (tracked component)'
      )
      expected = a_hash_including 'ver' => 1,
                                  'name' => 'Microsoft.ApplicationInsights.RemoteDependency',
                                  'time' => instance_of(String),
                                  'sampleRate' => 100.0,
                                  'data' => a_hash_including(
                                    'baseType' => 'RemoteDependencyData'
                                  )
      expect(dep_record).to expected
      expect(dep_record['tags']).to tags_expectation
      expect(dep_record.dig('data', 'baseData')).to base_data_expectation
    end

    it 'informs insights of the second request linked to the dependency' do
      rack_servers.get_request(:app1, '/anything')

      # @TODO This waits for a the request for the first service to be sent (as it wont get sent until the second has responded) - makes the rest easier knowing they are all there.  Needs a better way of doing it
      expect { insights_call_collector.flatten }.to eventually(include a_hash_including 'data' => a_hash_including('baseData' => a_hash_including('url' => "#{rack_servers.base_url_for(:app1)}/anything"))).pause_for(0.05).within(0.5)

      dep_record = insights_call_collector.flatten.detect { |r| r['data']['baseType'] == 'RemoteDependencyData' }
      original_operation_id = dep_record.dig('tags', 'ai.operation.id')
      parent_dep_id = dep_record.dig('data', 'baseData', 'id')
      app2_request = insights_call_collector.flatten.detect { |r| r['data']['baseType'] == 'RequestData' && r['data']['baseData']['url'] == "#{rack_servers.base_url_for(:app2)}/" }
      tags_expectation = a_hash_including 'ai.internal.sdkVersion' => "rb:#{ApplicationInsights::VERSION}",
                                          'ai.cloud.role' => 'fakerolename',
                                          'ai.cloud.roleInstance' => 'fakeroleinstance',
                                          'ai.operation.parentId' => parent_dep_id,
                                          'ai.operation.id' => original_operation_id
      base_data_expectation = a_hash_including 'ver' => 2,
                                               'id' => match(/\A\|[0-9a-f]{32}\.[0-9a-f]{16}\.\z/),
                                               'responseCode' => '200',
                                               'duration' => instance_of(String),
                                               'success' => true,
                                               'name' => 'GET /',
                                               'url' => "#{rack_servers.base_url_for(:app2)}/",
                                               'properties' => a_hash_including('httpMethod' => 'GET')


      expected = a_hash_including 'ver' => 1,
                                  'name' => 'Microsoft.ApplicationInsights.Request',
                                  'time' => instance_of(String),
                                  'sampleRate' => 100.0
      expect(app2_request).to expected
      expect(app2_request['tags']).to tags_expectation
      expect(app2_request.dig('data', 'baseData')).to base_data_expectation

    end

    # @TODO - What happens when another service hits us with the Request-Context set with an appId different to ours
  end
  context '2 service chain with first app failing' do
    # Here, we will configure 2 rack applications
    # Our test suite calls the first rack app with the tracking disabled (as we are not testing this part)
    # The first rack app will call the second
    #
    include_context 'rack servers' do
      rack_servers.register(:app1) do |env|
        rack_servers.get_request(:app2, '', disable_tracking: false)
        [500, {}, ['Internal Server Error']]
      end
      rack_servers.register(:app2) do |env|
        [200, {}, ['OK from rack app 2']]
      end
    end

    it 'inform insights of the start of the chain with correct status' do
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

  context '2 service chain with second app failing' do
    # Here, we will configure 2 rack applications
    # Our test suite calls the first rack app with the tracking disabled (as we are not testing this part)
    # The first rack app will call the second
    #
    include_context 'rack servers' do
      rack_servers.register(:app1) do |env|
        rack_servers.get_request(:app2, '', disable_tracking: false)
        [200, {}, ['OK from rack app 1 and rack app 2']]
      end
      rack_servers.register(:app2) do |env|
        [500, {}, ['Internal Server Error']]
      end
    end

    it 'informs insights of the external dependency between app1 and app2 with the correct status' do
      rack_servers.get_request(:app1, '/anything')

      # @TODO This waits for a the request for the first service to be sent (as it wont get sent until the second has responded) - makes the rest easier knowing they are all there.  Needs a better way of doing it
      expect { insights_call_collector.flatten }.to eventually(include a_hash_including 'data' => a_hash_including('baseData' => a_hash_including('url' => "#{rack_servers.base_url_for(:app1)}/anything"))).pause_for(0.05).within(0.5)

      app1_request_record = insights_call_collector.flatten.detect { |r| r['data']['baseData']['url'] == "#{rack_servers.base_url_for(:app1)}/anything" }
      original_operation_id = app1_request_record.dig('tags', 'ai.operation.id')
      parent_id = app1_request_record.dig('data', 'baseData', 'id')
      dep_record = insights_call_collector.flatten.detect { |r| r['data']['baseType'] == 'RemoteDependencyData' }
      tags_expectation = a_hash_including(
        'ai.internal.sdkVersion' => "rb:#{ApplicationInsights::VERSION}",
        'ai.cloud.role' => 'fakerolename',
        'ai.cloud.roleInstance' => 'fakeroleinstance',
        'ai.operation.parentId' => parent_id,
        'ai.operation.id' => original_operation_id,
        'ai.operation.name' => 'GET /anything'
      )
      base_data_expectation = a_hash_including(
        'ver' => 2,
        'id' => match(/\A\|[0-9a-f]{32}\.[0-9a-f]{16}\.\z/),
        'resultCode' => '500',
        'duration' => instance_of(String),
        'success' => false,
        'name' => "GET #{rack_servers.base_url_for(:app2)}/",
        'data' => "GET #{rack_servers.base_url_for(:app2)}/",
        'target' => "localhost:#{rack_servers.port_for(:app2)}",
        'type' => 'Http (tracked component)'
      )
      expected = a_hash_including 'ver' => 1,
                                  'name' => 'Microsoft.ApplicationInsights.RemoteDependency',
                                  'time' => instance_of(String),
                                  'sampleRate' => 100.0,
                                  'data' => a_hash_including(
                                    'baseType' => 'RemoteDependencyData'
                                  )
      expect(dep_record).to expected
      expect(dep_record['tags']).to tags_expectation
      expect(dep_record.dig('data', 'baseData')).to base_data_expectation
    end


  end
end