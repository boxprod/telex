require "test_helper"
require "open3"

class Telex::BootTest < ActiveSupport::TestCase
  test "an app without Action Mailbox boots and eager loads, and only sends" do
    output, status = Open3.capture2e({ "RAILS_ENV" => "production" }, RbConfig.ruby, file_fixture("../../boot/without_action_mailbox.rb").to_s)

    assert status.success?, output
    assert_equal "booted, lettermint delivery method\n[]\n", output
  end

  test "an app with Action Mailbox receives" do
    assert Telex.receiving?
    assert_equal "/rails/action_mailbox/lettermint/inbound_emails", Rails.application.routes.url_helpers.rails_lettermint_inbound_emails_path
  end
end
