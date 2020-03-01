require 'spec_helper'
require 'active_record'
require 'rack'
require 'et_azure_insights'
require 'et_azure_insights/adapters/active_record'

RSpec.describe 'Active record Integration' do
  include_context 'with stubbed insights api'
  around do |example|
    begin
      ActiveRecord::Base.establish_connection(adapter:  'sqlite3', database: File.expand_path('test.db', __dir__))
      ActiveRecord::Base.connection.execute <<-SQL
          CREATE TABLE IF NOT EXISTS test_models (
            id int,
            name varchar(50)
          );
      SQL
      EtAzureInsights::Adapters::ActiveRecord.setup
      example.run
    ensure
      EtAzureInsights::Adapters::ActiveRecord.uninstall
      ActiveRecord::Base.connection.execute 'DROP TABLE test_models;'
    end
  end
  include_context 'insights call collector'

  context '1 service which uses active record' do
    # Here, we will configure 2 rack applications
    # Our test suite calls the first rack app using net/http with the tracking disabled (as we are not testing this part)
    # The first rack app will call the second using typhoeus
    #
    include_context 'rack servers' do
      rack_servers.register(:app1) do |env|
        ActiveRecord::Base.connection.execute('SELECT * FROM test_models;')
        class TestModel < ActiveRecord::Base
        end
        [200, {}, ['OK from rack app 1 and rack app 2']]
      end
    end

    it 'informs insights of the dependency for active record' do
      rack_servers.get_request(:app1, '/anything')

      # @TODO This waits for a the request for the first service to be sent (as it wont get sent until the second has responded) - makes the rest easier knowing they are all there.  Needs a better way of doing it
      expect { insights_call_collector.flatten }.to eventually(include a_hash_including 'data' => a_hash_including('baseData' => a_hash_including('url' => "#{rack_servers.base_url_for(:app1)}/anything"))).pause_for(0.05).within(0.5)

      app1_request_record = insights_call_collector.flatten.detect { |r| r['data']['baseData']['url'] == "#{rack_servers.base_url_for(:app1)}/anything" }
      original_operation_id = app1_request_record.dig('tags', 'ai.operation.id')
      parent_id = app1_request_record.dig('data', 'baseData', 'id')
      dep_record = insights_call_collector.flatten.detect { |r| r['data']['baseType'] == 'RemoteDependencyData' && r.dig('data', 'baseData', 'data') == 'SELECT * FROM test_models;' }
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
        'name' => "SELECT * FROM test_models;",
        'data' => "SELECT * FROM test_models;",
        'target' => ":",
        'type' => 'SQLite'
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