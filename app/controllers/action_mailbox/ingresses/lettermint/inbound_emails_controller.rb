module ActionMailbox
  # Ingests inbound emails from Lettermint, whose webhooks carry a signed link to the original
  # message rather than the message itself. The link is fetched by Telex::IngestJob.
  #
  # Authenticates requests by their X-Lettermint-Signature header.
  #
  # Returns:
  #
  # - <tt>204 No Content</tt> once the message is queued for download, and for every other event
  # - <tt>401 Unauthorized</tt> if the signature is wrong or more than 5 minutes old
  # - <tt>404 Not Found</tt> if Action Mailbox is not configured to accept inbound emails from Lettermint
  # - <tt>422 Unprocessable Entity</tt> if an inbound event has no link to the message
  # - <tt>500 Server Error</tt> if the webhook secret is missing, or the Active Job backend is unavailable
  class Ingresses::Lettermint::InboundEmailsController < ActionMailbox::BaseController
    before_action :authenticate

    def create
      if payload["event"] == "message.inbound"
        data = payload.fetch("data", {})
        url = data.dig("raw", "url")
        return head :unprocessable_entity if url.blank?

        Telex::IngestJob.perform_later(url, recipient: data["recipient"], spam_score: data["spam_score"], spam: data["is_spam"])
      end

      head :no_content
    end

    private
      # The payload holds the message, and links Lettermint asks to keep secret: none of it goes to the logs.
      def process_action(...)
        request.set_header "action_dispatch.parameter_filter", Rails.application.config.filter_parameters + [ /\Adata\z/ ]
        super
      end

      def payload
        @payload ||= JSON.parse(request.raw_post)
      end

      def authenticate
        head :unauthorized unless Telex::Signature.new(request.headers["X-Lettermint-Signature"], secret: secret).valid?(request.raw_post)
      end

      def secret
        Telex.webhook_secret.presence || raise(ArgumentError, <<~MESSAGE.squish)
          Missing the Lettermint webhook secret. Set lettermint.webhook_secret in your application's
          encrypted credentials or provide the LETTERMINT_WEBHOOK_SECRET environment variable.
        MESSAGE
      end
  end
end
