# Boots an app that loads neither Action Mailbox nor Active Storage, eager loading as in production.
require "bundler/setup"
require "rails"
require "action_controller/railtie"
require "action_mailer/railtie"
require "active_job/railtie"
require "telex"

class WithoutActionMailbox < Rails::Application
  config.root = __dir__
  config.eager_load = true
  config.logger = Logger.new(nil)
  config.secret_key_base = "test"
end

WithoutActionMailbox.initialize!
Rails.application.eager_load!
puts ActionMailer::Base.delivery_methods.key?(:lettermint) ? "booted, lettermint delivery method" : "booted, no delivery method"
puts Rails.application.routes.routes.map { |route| route.path.spec.to_s }.grep(/lettermint/).inspect
