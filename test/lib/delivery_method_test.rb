require "test_helper"

class Telex::DeliveryMethodTest < ActiveSupport::TestCase
  test "sends through Lettermint's SMTP relay with the project's token" do
    settings = ActionMailer::Base.lettermint_settings
    assert_equal "smtp.lettermint.co", settings[:address]
    assert_equal 587, settings[:port]
    assert_equal "lettermint", settings[:user_name]
    assert_equal "lm_test", settings[:password]
    assert settings[:enable_starttls]
  end

  test "a mailer set to it delivers over SMTP" do
    NoticeMailer.delivery_method = :lettermint
    delivery = NoticeMailer.hello.message.delivery_method
    assert_kind_of Mail::SMTP, delivery
    assert_equal "smtp.lettermint.co", delivery.settings[:address]
  ensure
    NoticeMailer.delivery_method = :test
  end
end
