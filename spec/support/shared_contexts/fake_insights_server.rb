require 'zlib'
require 'rack'
RSpec.shared_context 'fake insights server' do |*args, &block|
  let(:fake_insights_server) { FakeInsightsServer.new }

  class FakeInsightsServer
    attr_reader :request_data, :remote_dependency_data

    def initialize
      self.request_data = RequestDataCollection.new
      self.remote_dependency_data = RemoteDependencyDataCollection.new
    end

    def call(env)
      request = ::Rack::Request.new(env)
      raw_data = Zlib.gunzip(request.body.read)
      json_data = JSON.parse(raw_data)
      record(json_data)
      #calls << JSON.parse(data)
      [200, {}, ['']]
    end

    private

    attr_writer :request_data, :remote_dependency_data

    def record(json_data)
      if json_data.is_a?(Array)
        json_data.each {|d| record(d) }
        return
      end

      case json_data.dig('data', 'baseType')
      when 'RequestData' then request_data.import(json_data, self)
      when 'RemoteDependencyData' then remote_dependency_data.import(json_data, self)
      else raise "Unknown type #{json_data.dig('data', 'baseType')}"
      end
    end

    class BaseCollection
      def initialize(contents = [])
        self.storage = contents
      end

      def find_by(attrs, timeout: 1, sleep: 0.05)
        wait_for(timeout: timeout, sleep: sleep) do
          find_all_by(attrs).first
        end
      rescue Timeout::Error
        nil
      end

      def find_all_by(attrs)
        storage.select do |entry|
          matches?(attrs, entry.to_h)
        end
      end

      def where(attrs)
        self.class.new(find_all_by(attrs))
      end

      def wait_for(timeout: 1, sleep: 0.05)
        Timeout.timeout(timeout) do
          loop do
            value = yield
            break value unless value.nil?
            sleep sleep
          end
        end
      end

      private

      def matches?(spec, entry)
        spec.all? do |(spec_key, spec_value)|
          next false unless entry.is_a?(Hash) && entry.key?(spec_key.to_s)
          if spec_value.is_a?(Hash)
            matches?(spec_value, entry[spec_key.to_s])
          else
            spec_value.is_a?(Regexp) ? entry[spec_key.to_s] =~ spec_value : entry[spec_key.to_s] == spec_value
          end
        end
      end

      attr_accessor :storage
    end
    class RequestDataCollection < BaseCollection
      def import(data, root_server)
        storage.push RequestData.new(data, root_server)
      end
    end

    class RemoteDependencyDataCollection < BaseCollection
      def import(data, root_server)
        storage.push RemoteDependencyData.new(data, root_server)
      end

      def find_sidekiq
        find_by(data: { baseData: { type: 'Sidekiq (tracked component)' } })
      end

      def find_http
        find_by(data: { baseData: { type: 'Http (tracked component)' } })
      end
    end

    class BaseTelemetry
      def initialize(attrs, root_server)
        self.attrs = attrs
        self.root_server = root_server
      end

      def to_h
        attrs
      end

      delegate :dig, :[], to: :attrs

      private

      attr_accessor :attrs, :root_server
    end
    class RequestData < BaseTelemetry
      def remote_dependencies
        # flatten.detect { |r| r['data']['baseType'] == 'RemoteDependencyData' && r.dig('tags', 'ai.operation.parentId') == request.dig('data', 'baseData', 'id') }
        root_server.remote_dependency_data.where(tags: { 'ai.operation.parentId': attrs.dig('data', 'baseData', 'id') })
      end
    end

    class RemoteDependencyData < BaseTelemetry
      def sidekiq_request
        # flatten.detect { |r| r['data']['baseType'] == 'RequestData' && r.dig('tags', 'ai.operation.parentId') == dependency.dig('data', 'baseData', 'id') && r['data']['baseData']['url'] =~/\Asidekiq:\/\// }
        root_server.request_data.find_by(tags: { 'ai.operation.parentId': dig('data', 'baseData', 'id') }, data: { baseData: { url:  /\Asidekiq:\/\//} })
      end

      def http_request
        root_server.request_data.find_by(tags: { 'ai.operation.parentId': dig('data', 'baseData', 'id') }, data: { baseData: { url:  /\Ahttp(s)?:\/\//} })
      end
    end
  end


  def insights_flush
    EtAzureInsights::Client.client.flush(wait: true)
  end

  before do
    stub_request(:post, 'https://dc.services.visualstudio.com/v2/track')
      .to_rack(fake_insights_server)
  end
  after do
    insights_flush
  end
end