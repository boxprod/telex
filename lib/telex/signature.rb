require "openssl"

module Telex
  # The X-Lettermint-Signature header: "t=<unix seconds>,v1=<hex HMAC-SHA256 of "<t>.<raw body>">",
  # keyed with the webhook secret as given, whsec_ prefix included.
  class Signature
    TOLERANCE = 5.minutes

    def self.generate(body, secret:, at: Time.now)
      timestamp = at.to_i
      "t=#{timestamp},v1=#{digest(timestamp, body, secret)}"
    end

    def self.digest(timestamp, body, secret)
      OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{body}")
    end

    def initialize(header, secret:)
      @parts = header.to_s.split(",").to_h { |part| part.split("=", 2).map(&:strip) }
      @secret = secret
    end

    def valid?(body, now: Time.now)
      timestamp = Integer(@parts["t"], exception: false)
      return false unless timestamp && @parts["v1"]

      (now.to_i - timestamp).abs <= TOLERANCE &&
        ActiveSupport::SecurityUtils.secure_compare(@parts["v1"], self.class.digest(timestamp, body, @secret))
    end
  end
end
