# Wrap each request example in an explicit Bullet request lifecycle so that
# N+1 queries and unused eager-loads fail the spec (Bullet.raise = true, set
# globally in config/environments/test.rb).
#
# Note: Bullet.perform_out_of_channel_notifications is intentionally not called —
# it triggers a `collection' for nil error on Ruby 4.0 / Bullet 8.x. The N+1
# detection and `raise` behavior happens during end_request regardless.
if defined?(Bullet)
  RSpec.configure do |config|
    config.before(:each, type: :request) do
      Bullet.start_request
    end

    config.after(:each, type: :request) do
      Bullet.end_request
    end
  end
end
