require "test_helper"

class Telex::SignatureTest < ActiveSupport::TestCase
  BODY = '{"id":"abc","event":"message.delivered"}'

  test "matches Lettermint's documented construction" do
    expected = OpenSSL::HMAC.hexdigest("SHA256", "whsec_x", "1704067200.#{BODY}")
    assert_equal "t=1704067200,v1=#{expected}", Telex::Signature.generate(BODY, secret: "whsec_x", at: Time.at(1704067200))
  end

  test "accepts its own signature within five minutes either way" do
    now = Time.at(1704067200)
    header = Telex::Signature.generate(BODY, secret: "whsec_x", at: now)
    assert Telex::Signature.new(header, secret: "whsec_x").valid?(BODY, now: now + 5.minutes)
    assert Telex::Signature.new(header, secret: "whsec_x").valid?(BODY, now: now - 5.minutes)
    assert_not Telex::Signature.new(header, secret: "whsec_x").valid?(BODY, now: now + 301)
  end

  test "refuses another secret, another body, or a malformed header" do
    header = Telex::Signature.generate(BODY, secret: "whsec_x")
    assert_not Telex::Signature.new(header, secret: "whsec_y").valid?(BODY)
    assert_not Telex::Signature.new(header, secret: "whsec_x").valid?(BODY + " ")
    [ nil, "", "v1=abc", "t=now,v1=abc", "t=1704067200" ].each do |malformed|
      assert_not Telex::Signature.new(malformed, secret: "whsec_x").valid?(BODY), malformed.inspect
    end
  end
end
