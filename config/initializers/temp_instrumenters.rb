# frozen_string_literal: true

ActiveSupport::Notifications.subscribe 'enqueue.active_job' do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  event
end
ActiveSupport::Notifications.subscribe 'enqueued_at.active_job' do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  event
end
