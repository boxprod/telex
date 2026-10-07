require "net/http"

module Telex
  # Fetches a message's original source from the signed URL in the webhook. The URL needs no
  # credentials, so it is a secret until it expires, 28 days after the message arrived.
  class Download
    # Worth trying again later.
    class Error < StandardError; end

    # The link has expired or was never valid: trying again will not help.
    class Gone < Error; end

    MAX_REDIRECTS = 3

    def fetch(url, redirects: MAX_REDIRECTS)
      uri = URI(url)
      raise Gone, "Lettermint gave an address that is not HTTPS" unless uri.is_a?(URI::HTTPS)

      case response = perform(uri)
      when Net::HTTPSuccess
        response.body.b
      when Net::HTTPRedirection
        raise Error, "Lettermint redirected too many times" if redirects.zero?
        fetch(URI.join(uri, response["location"]).to_s, redirects: redirects - 1)
      when Net::HTTPForbidden, Net::HTTPNotFound, Net::HTTPGone
        raise Gone, "Lettermint answered #{response.code} for the message's source"
      else
        raise Error, "Lettermint answered #{response.code} for the message's source"
      end
    rescue Timeout::Error, SystemCallError, SocketError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse => error
      raise Error, "Lettermint could not be reached (#{error.class})"
    end

    private
      def perform(uri)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
          http.request(Net::HTTP::Get.new(uri))
        end
      end
  end
end
