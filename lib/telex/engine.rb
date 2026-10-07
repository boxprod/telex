module Telex
  # Not isolated: the ingress lives in Action Mailbox's namespace and its route in the app's,
  # next to the ones Rails ships for other providers.
  class Engine < ::Rails::Engine
    # config.action_mailer.delivery_method = :lettermint
    initializer "telex.delivery_method" do
      ActiveSupport.on_load(:action_mailer) do
        add_delivery_method :lettermint, Mail::SMTP, Telex::SMTP_SETTINGS.merge(password: Telex.api_token)
      end
    end
  end
end
