require "test_helper"

class Telex::IngestJobTest < ActiveJob::TestCase
  URL = "https://storage.lettermint.co/inbound/raw/1?signature=s"

  setup { @download.sources[URL] = file_fixture("reply.eml").binread }

  test "hands the message to Action Mailbox, with the address it was delivered to" do
    Telex::IngestJob.perform_now(URL, recipient: "bcc@reply.example.com", spam_score: 1.2, spam: false)

    inbound_email = ActionMailbox::InboundEmail.last
    assert_equal "reply-1@example.com", inbound_email.message_id
    assert_includes inbound_email.mail.recipients, "bcc@reply.example.com"
    assert_equal "no", inbound_email.mail["X-Lettermint-Spam"].value
    assert_equal "1.2", inbound_email.mail["X-Lettermint-Spam-Score"].value
    assert_equal "The total looks right now, thanks.", inbound_email.mail.body.decoded.strip
  end

  test "keeps a message once when the webhook comes twice" do
    assert_difference -> { ActionMailbox::InboundEmail.count }, 1 do
      2.times { Telex::IngestJob.perform_now(URL, recipient: "reply+quote-12@reply.example.com") }
    end
  end

  test "tries again later when Lettermint cannot be reached" do
    @download.failure = Telex::Download::Error.new("Lettermint answered 503 for the message's source")
    assert_enqueued_with(job: Telex::IngestJob) { Telex::IngestJob.perform_now(URL) }
    assert_equal 0, ActionMailbox::InboundEmail.count
  end

  test "gives up at once when the link has expired" do
    @download.failure = Telex::Download::Gone.new("Lettermint answered 403 for the message's source")
    assert_no_enqueued_jobs { Telex::IngestJob.perform_now(URL) }
    assert_equal 0, ActionMailbox::InboundEmail.count
  end

  test "does not log the link" do
    assert_not Telex::IngestJob.log_arguments?
  end
end
