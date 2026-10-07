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

    # An app that only sends does not load Action Mailbox: the ingress is left out, or eager
    # loading it would stop the app from booting.
    initializer "telex.without_action_mailbox", before: :set_autoload_paths do
      Rails.autoloaders.main.ignore(root.join("app/controllers/action_mailbox")) unless Telex.receiving?
    end
  end
end
