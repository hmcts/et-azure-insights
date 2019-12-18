require 'sidekiq'
require 'et_azure_insights/adapters/net_http'
RSpec.describe 'Sidekiq integration' do
  include_context 'with stubbed insights api'
  around do |example|
    begin
      EtAzureInsights::Adapters::NetHttp.setup
      example.run
    ensure
      EtAzureInsights::Adapters::NetHttp.uninstall
    end
  end
  include_context 'fake insights server'
  context 'rack to sidekiq to http to 2nd rack' do
    include_context 'rack servers' do
      rack_servers.register(:app1) do |env|
        FakeWorker.perform_async
        [200, {}, ['OK from rack app 1 and scheduled call to app 2']]
      end
      rack_servers.register(:app2) do |env|
        [200, {}, ['OK from rack app 2']]
      end
    end

    include_context 'fake sidekiq environment' do
      r = rack_servers
      FakeWorker = Class.new do
        include Sidekiq::Worker
        sidekiq_options queue: 'my_queue'

        define_method :perform do
          r.get_request(:app2, '/from_sidekiq', disable_tracking: false)
        end
      end
    end
    it 'inform insights of the start of the chain' do
      rack_servers.get_request(:app1, '/path1')
      insights_flush

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
                                      'url' => "#{rack_servers.base_url_for(:app1)}/path1",
                                      'name' => 'GET /path1',
                                      'properties' => a_hash_including(
                                        'httpMethod' => 'GET'
                                      )
                                    )
                                  )
      expect(fake_insights_server.request_data.find_by(data: { baseData: {name: 'GET /path1'}}).to_h).to expected
    end

    it 'informs insights of the external dependency between app1 and the sidekiq worker with calling the worker' do
      rack_servers.get_request(:app1, '/path2')
      insights_flush
      first_request = fake_insights_server.request_data.find_by(data: { baseData: {name: 'GET /path2'}})
      dep_record = first_request.remote_dependencies.find_by(data: { baseData: { type: 'Sidekiq (tracked component)' } })
      tags_expectation = a_hash_including(
        'ai.internal.sdkVersion' => "rb:#{ApplicationInsights::VERSION}",
        'ai.cloud.role' => 'fakerolename',
        'ai.cloud.roleInstance' => 'fakeroleinstance',
        'ai.operation.parentId' => first_request.dig('data', 'baseData', 'id'),
        'ai.operation.id' => first_request.dig('tags', 'ai.operation.id'),
        'ai.operation.name' => 'GET /path2'
      )
      base_data_expectation = a_hash_including(
        'ver' => 2,
        'id' => match(/\A\|[0-9a-f]{32}\.[0-9a-f]{16}\.\z/),
        'resultCode' => '200',
        'duration' => instance_of(String),
        'success' => true,
        'name' => match(/\APERFORM \/my_queue\/FakeWorker\/[0-9a-f]{24}\z/),
        'data' => match(/\APERFORM \/my_queue\/FakeWorker\/[0-9a-f]{24}\z/),
        'type' => 'Sidekiq (tracked component)'
      )
      expected = a_hash_including 'ver' => 1,
                                  'name' => 'Microsoft.ApplicationInsights.RemoteDependency',
                                  'time' => instance_of(String),
                                  'sampleRate' => 100.0,
                                  'data' => a_hash_including(
                                    'baseType' => 'RemoteDependencyData'
                                  )
      expect(dep_record.to_h).to expected
      expect(dep_record['tags']).to tags_expectation
      expect(dep_record.dig('data', 'baseData')).to base_data_expectation
    end

    it 'informs insights of the sidekiq worker job linked to the dependency' do
      # Act - Call the app and do the work the sidekiq process would normally do in a seperate thread
      rack_servers.get_request(:app1, '/path3')
      Thread.new { FakeWorker.drain }.join
      insights_flush

      first_request = fake_insights_server.request_data.find_by(data: { baseData: {name: 'GET /path3'}})
      sidekiq_request = first_request.remote_dependencies.find_sidekiq.sidekiq_request

      tags_expectation = a_hash_including 'ai.internal.sdkVersion' => "rb:#{ApplicationInsights::VERSION}",
                                          'ai.cloud.role' => 'fakerolename',
                                          'ai.cloud.roleInstance' => 'fakeroleinstance',
                                          'ai.operation.id' => first_request.dig('tags', 'ai.operation.id')
      base_data_expectation = a_hash_including 'ver' => 2,
                                               'id' => match(/\A\|[0-9a-f]{32}\.[0-9a-f]{16}\.\z/),
                                               'responseCode' => '200',
                                               'duration' => instance_of(String),
                                               'success' => true,
                                               'name' => match(/\APERFORM \/my_queue\/FakeWorker\/[0-9a-f]{24}\z/),
                                               'url' => match(/\Asidekiq:\/\/my_queue\/FakeWorker\/[0-9a-f]{24}\z/),
                                               'properties' => a_hash_including('httpMethod' => 'PERFORM')


      expected = a_hash_including 'ver' => 1,
                                  'name' => 'Microsoft.ApplicationInsights.Request',
                                  'time' => instance_of(String),
                                  'sampleRate' => 100.0
      expect(sidekiq_request.to_h).to expected
      expect(sidekiq_request['tags']).to tags_expectation
      expect(sidekiq_request.dig('data', 'baseData')).to base_data_expectation

    end

    it 'informs insights of the http request performed by the sidekiq worker' do
      # Act - Call the app and do the work the sidekiq process would normally do in a seperate thread
      rack_servers.get_request(:app1, '/path4')
      Thread.new { FakeWorker.drain }.join
      insights_flush

      first_request = fake_insights_server.request_data.find_by(data: { baseData: {name: 'GET /path4'}})
      dep_record = first_request.remote_dependencies.find_sidekiq.sidekiq_request.remote_dependencies.find_http

      tags_expectation = a_hash_including(
        'ai.internal.sdkVersion' => "rb:#{ApplicationInsights::VERSION}",
        'ai.cloud.role' => 'fakerolename',
        'ai.cloud.roleInstance' => 'fakeroleinstance',
        'ai.operation.id' => first_request.dig('tags', 'ai.operation.id'),
        'ai.operation.name' => /\APERFORM \/my_queue\/FakeWorker\/[0-9a-f]{16}/
      )
      base_data_expectation = a_hash_including(
        'ver' => 2,
        'id' => match(/\A\|[0-9a-f]{32}\.[0-9a-f]{16}\.\z/),
        'resultCode' => '200',
        'duration' => instance_of(String),
        'success' => true,
        'name' => "GET #{rack_servers.base_url_for(:app2)}/from_sidekiq",
        'data' => "GET #{rack_servers.base_url_for(:app2)}/from_sidekiq",
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
      expect(dep_record.to_h).to expected
      expect(dep_record['tags']).to tags_expectation
      expect(dep_record.dig('data', 'baseData')).to base_data_expectation
    end

    it 'informs insights of the rack request performed by net/http via the sidekiq worker' do
      # Act - Call the app and do the work the sidekiq process would normally do in a seperate thread
      rack_servers.get_request(:app1, '/path5')
      Thread.new { FakeWorker.drain }.join
      insights_flush

      first_request = fake_insights_server.request_data.find_by(data: { baseData: {name: 'GET /path5'}})
      rack_record = first_request.remote_dependencies.find_sidekiq.sidekiq_request.remote_dependencies.find_http.http_request

      tags_expectation = a_hash_including(
        'ai.internal.sdkVersion' => "rb:#{ApplicationInsights::VERSION}",
        'ai.cloud.role' => 'fakerolename',
        'ai.cloud.roleInstance' => 'fakeroleinstance',
        'ai.operation.id' => first_request.dig('tags', 'ai.operation.id'),
        'ai.operation.name' => 'GET /from_sidekiq'
      )
      base_data_expectation = a_hash_including(
        'ver' => 2,
        'id' => match(/\A|[0-9a-f]{32}\./),
        'duration' => instance_of(String),
        'responseCode' => '200',
        'success' => true,
        'url' => "#{rack_servers.base_url_for(:app2)}/from_sidekiq",
        'name' => 'GET /from_sidekiq',
        'properties' => a_hash_including(
          'httpMethod' => 'GET'
        )
      )
      expected = a_hash_including 'ver' => 1,
                                  'name' => 'Microsoft.ApplicationInsights.Request',
                                  'time' => instance_of(String),
                                  'sampleRate' => 100.0,
                                  'data' => a_hash_including(
                                    'baseType' => 'RequestData'
                                  )
      expect(rack_record.to_h).to expected
      expect(rack_record['tags']).to tags_expectation
      expect(rack_record.dig('data', 'baseData')).to base_data_expectation
    end



  end
end