require 'random-port'
require 'rack'
require 'et_azure_insights/adapters/rack'
# A shared context for managing multiple rack servers.
# This will start all servers registered before the context and
# stop them after the context.
# Access to the base_url is available using rack_servers.base_url_for(key)
#
# @example
#
#   include_context 'rack servers' do
#    rack_servers.register(:app1) do |env|
#      [200, {}, ['OK from rack app 1']]
#    end
#    rack_servers.register(:app2) do |env|
#      [200, {}, ['OK from rack app 2']]
#    end
#  end
#
#  The example above will register app1 and app2
#  Before the context starts, a webrick server will be created for each and
#  the rack middleware for this project is included.
#
RSpec.shared_context 'rack servers' do |*args|
  class ServerCollection
    def initialize
      self.rack_apps = {}
      self.random_port_pool = RandomPort::Pool::SINGLETON
    end

    def register(key, &block)
      wrapped_rack_app = Rack::Builder.new do
        use ::EtAzureInsights::Adapters::Rack
        run block
      end
      rack_apps[key] = { app: wrapped_rack_app }
    end

    def start_all
      rack_apps.each_pair do |key, value|
        value[:port] = random_port_pool.acquire
        value[:rack_server] = Rack::Server.new(
          app: value[:app],
          server: 'webrick',
          Port: value[:port]
        )
        value[:thread] = Thread.new do
          value[:rack_server].start
        end
      end
    end

    def stop_all
      rack_apps.values.each do |v|
        v[:thread].kill
      end
    end

    def base_url_for(key)
      "http://localhost:#{port_for(key)}"
    end

    def port_for(key)
      raise KeyError, "'#{key}' is not registered" unless rack_apps.key?(key)

      rack_apps[key][:port]
    end

    def get_request(key, path, disable_tracking: true)
      uri = URI.parse("#{base_url_for(key)}#{path}")
      headers = {}
      headers['et-azure-insights-no-track'] = 'true' if disable_tracking
      request = Net::HTTP::Get.new(uri, headers)
      http = Net::HTTP.new uri.hostname, uri.port
      http.open_timeout = 500
      http.read_timeout = 500
      http.max_retries = 0
      response = http.request(request)
      http.finish if http.started?
      response
    end

    private

    attr_accessor :rack_apps, :random_port_pool

  end

  cattr_accessor :rack_servers
  self.rack_servers = ServerCollection.new

  def random_port_pool
    @random_port_pool ||= RandomPort::Pool.new
  end

  def rack_servers
    self.class.rack_servers
  end

  before(:all) do
    rack_servers.start_all
    sleep 1
  end
  after(:all) do
    rack_servers.stop_all
  end

end