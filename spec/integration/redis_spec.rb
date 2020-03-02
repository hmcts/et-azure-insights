require 'spec_helper'
require 'redis'
require 'rack'
require 'et_azure_insights'
require 'et_azure_insights/adapters/redis'

RSpec.describe 'Redis Integration' do
  include_context 'with stubbed insights api'
  around do |example|
    begin
      EtAzureInsights::Adapters::Redis.setup
      example.run
    ensure
      EtAzureInsights::Adapters::Redis.uninstall
    end
  end
  include_context 'insights call collector'

  context '1 service which uses redis' do
    # Here, we will configure 2 rack applications
    # Our test suite calls the first rack app using net/http with the tracking disabled (as we are not testing this part)
    # The first rack app will call the second using typhoeus
    #
    include_context 'rack servers' do
      rack_servers.register(:app1) do |env|
        client = ::Redis.new
        client.sadd('key', 'value')
        [200, {}, ['OK from rack app 1']]
      end
    end

    it 'informs insights of the dependency for redis' do
      rack_servers.get_request(:app1, '/anything')

      # @TODO This waits for a the request for the first service to be sent (as it wont get sent until the second has responded) - makes the rest easier knowing they are all there.  Needs a better way of doing it
      expect { insights_call_collector.flatten }.to eventually(include a_hash_including 'data' => a_hash_including('baseData' => a_hash_including('url' => "#{rack_servers.base_url_for(:app1)}/anything"))).pause_for(0.05).within(0.5)

      app1_request_record = insights_call_collector.flatten.detect { |r| r['data']['baseData']['url'] == "#{rack_servers.base_url_for(:app1)}/anything" }
      original_operation_id = app1_request_record.dig('tags', 'ai.operation.id')
      parent_id = app1_request_record.dig('data', 'baseData', 'id')
      dep_record = insights_call_collector.flatten.detect { |r| r['data']['baseType'] == 'RemoteDependencyData' && r.dig('data', 'baseData', 'data') == 'sadd' }
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
        'name' => "sadd",
        'data' => "sadd",
        'target' => "redis://127.0.0.1:6379",
        'type' => 'redis'
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

    context 'with a failing connection' do
      before do
        expect(Redis::Connection::Memory).to receive(:connect).and_raise(::Redis::CannotConnectError)
      end

      it 'informs insights of the dependency for redis' do
        rack_servers.get_request(:app1, '/anything')

        # @TODO This waits for a the request for the first service to be sent (as it wont get sent until the second has responded) - makes the rest easier knowing they are all there.  Needs a better way of doing it
        expect { insights_call_collector.flatten }.to eventually(include a_hash_including 'data' => a_hash_including('baseData' => a_hash_including('url' => "#{rack_servers.base_url_for(:app1)}/anything"))).pause_for(0.05).within(0.5)

        app1_request_record = insights_call_collector.flatten.detect { |r| r['data']['baseData']['url'] == "#{rack_servers.base_url_for(:app1)}/anything" }
        original_operation_id = app1_request_record.dig('tags', 'ai.operation.id')
        parent_id = app1_request_record.dig('data', 'baseData', 'id')
        dep_record = insights_call_collector.flatten.detect { |r| r['data']['baseType'] == 'RemoteDependencyData' && r.dig('data', 'baseData', 'data') == 'sadd' }
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
          'name' => "sadd",
          'data' => "sadd",
          'target' => "redis://127.0.0.1:6379",
          'type' => 'redis'
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
end