require "test_helper"

class Telex::DownloadTest < ActiveSupport::TestCase
  # Answers from a list instead of the network, and keeps the addresses asked for.
  class Recorded < Telex::Download
    attr_accessor :responses, :requested

    private
      def perform(uri)
        requested << uri.to_s
        response = responses.shift
        response.is_a?(Exception) ? raise(response) : response
      end
  end

  URL = "https://storage.lettermint.co/inbound/raw/1?signature=s"

  setup do
    @download = Recorded.new
    @download.requested = []
  end

  test "returns the source as bytes" do
    @download.responses = [ net_response(Net::HTTPOK, "200", "From: ana@example.com\r\n\r\nHé") ]
    source = @download.fetch(URL)
    assert_equal Encoding::BINARY, source.encoding
    assert_equal "From: ana@example.com\r\n\r\nHé".b, source
  end

  test "follows a redirect to storage" do
    redirect = net_response(Net::HTTPFound, "302", "").tap { |response| response["location"] = "https://bucket.example.com/1.eml" }
    @download.responses = [ redirect, net_response(Net::HTTPOK, "200", "source") ]
    assert_equal "source", @download.fetch(URL)
    assert_equal [ URL, "https://bucket.example.com/1.eml" ], @download.requested
  end

  test "tells an expired link from an outage" do
    @download.responses = [ net_response(Net::HTTPForbidden, "403", "") ]
    assert_raises(Telex::Download::Gone) { @download.fetch(URL) }

    @download.responses = [ net_response(Net::HTTPServiceUnavailable, "503", "") ]
    error = assert_raises(Telex::Download::Error) { @download.fetch(URL) }
    assert_not_kind_of Telex::Download::Gone, error
  end

  test "takes a network failure for an outage" do
    @download.responses = [ Net::OpenTimeout.new("execution expired") ]
    error = assert_raises(Telex::Download::Error) { @download.fetch(URL) }
    assert_not_kind_of Telex::Download::Gone, error
    assert_includes error.message, "Net::OpenTimeout"
  end

  test "only fetches over HTTPS" do
    assert_raises(Telex::Download::Gone) { @download.fetch("http://storage.lettermint.co/inbound/raw/1") }
    assert_empty @download.requested
  end

  private
    def net_response(klass, code, body)
      klass.new("1.1", code, "").tap do |response|
        response.instance_variable_set(:@body, body)
        response.instance_variable_set(:@read, true)
      end
    end
end
