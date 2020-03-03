require 'active_job'
RSpec.configure do |c|
  c.before do
    ActiveJob::Base.queue_adapter = :sidekiq
  end
end
