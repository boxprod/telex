require "telex/version"
require "telex/signature"
require "telex/download"
require "telex/engine"

# Email for our Rails apps through Lettermint: Action Mailer sends over its SMTP relay,
# Action Mailbox receives from its inbound webhooks.
module Telex
  SMTP_SETTINGS = {
    address: "smtp.lettermint.co",
    port: 587,
    user_name: "lettermint",
    authentication: :plain,
    enable_starttls: true
  }.freeze

  class << self
    # The project's API token, which is also the SMTP password.
    def api_token
      Rails.application.credentials.dig(:lettermint, :api_token) || ENV["LETTERMINT_API_TOKEN"]
    end

    # The inbound route's webhook secret, whsec_ prefix included.
    def webhook_secret
      Rails.application.credentials.dig(:lettermint, :webhook_secret) || ENV["LETTERMINT_WEBHOOK_SECRET"]
    end

    # Whether the app loads Action Mailbox, without which Telex only sends.
    def receiving?
      defined?(ActionMailbox::Engine) ? true : false
    end

    # Replaced in tests; anything that answers #fetch(url) with the message's source.
    attr_writer :download

    def download
      @download ||= Download.new
    end
  end
end
