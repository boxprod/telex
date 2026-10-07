module Telex
  # Signs requests the way Lettermint does, for integration tests of the inbound webhook.
  # To test a mailbox, Action Mailbox's own receive_inbound_email_from_mail is simpler.
  module TestHelper
    def lettermint_webhook_headers(body, secret: Telex.webhook_secret, event: JSON.parse(body)["event"], at: Time.now)
      {
        "Content-Type" => "application/json",
        "X-Lettermint-Signature" => Telex::Signature.generate(body, secret: secret, at: at),
        "X-Lettermint-Event" => event,
        "X-Lettermint-Delivery" => at.to_i.to_s,
        "X-Lettermint-Attempt" => "1"
      }
    end

    def lettermint_inbound_payload(recipient:, raw_url: "https://storage.lettermint.co/inbound/raw/test?signature=test", **data)
      {
        id: SecureRandom.uuid,
        event: "message.inbound",
        timestamp: Time.now.utc.iso8601(3),
        data: { recipient: recipient, raw: { url: raw_url, expires_at: 28.days.from_now.iso8601 }, is_spam: false, spam_score: 0.0, **data }
      }.to_json
    end
  end
end
