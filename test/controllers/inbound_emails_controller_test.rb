require "test_helper"

class ActionMailbox::Ingresses::Lettermint::InboundEmailsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { @body = lettermint_inbound_payload(recipient: "reply+quote-12@reply.example.com", spam_score: 1.2) }

  test "queues the message for download" do
    assert_enqueued_with(job: Telex::IngestJob,
        args: [ "https://storage.lettermint.co/inbound/raw/test?signature=test", { recipient: "reply+quote-12@reply.example.com", spam_score: 1.2, spam: false } ]) do
      post rails_lettermint_inbound_emails_path, params: @body, headers: lettermint_webhook_headers(@body)
    end
    assert_response :no_content
  end

  test "delivers the message to its mailbox once the job has run" do
    @download.sources["https://storage.lettermint.co/inbound/raw/test?signature=test"] = file_fixture("reply.eml").binread

    perform_enqueued_jobs do
      post rails_lettermint_inbound_emails_path, params: @body, headers: lettermint_webhook_headers(@body)
    end

    assert ActionMailbox::InboundEmail.last.delivered?
  end

  test "refuses a wrong signature" do
    assert_no_enqueued_jobs do
      post rails_lettermint_inbound_emails_path, params: @body, headers: lettermint_webhook_headers(@body, secret: "whsec_other")
    end
    assert_response :unauthorized
  end

  test "refuses a body that is not the one signed" do
    headers = lettermint_webhook_headers(@body)
    post rails_lettermint_inbound_emails_path, params: @body.sub("reply+quote-12", "reply+quote-13"), headers: headers
    assert_response :unauthorized
  end

  test "refuses a signature older than five minutes" do
    post rails_lettermint_inbound_emails_path, params: @body, headers: lettermint_webhook_headers(@body, at: 6.minutes.ago)
    assert_response :unauthorized
  end

  test "refuses a request without a signature" do
    post rails_lettermint_inbound_emails_path, params: @body, headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized
  end

  test "accepts other events without doing anything" do
    body = { id: "1", event: "message.delivered", timestamp: Time.now.utc.iso8601, data: {} }.to_json
    assert_no_enqueued_jobs do
      post rails_lettermint_inbound_emails_path, params: body, headers: lettermint_webhook_headers(body)
    end
    assert_response :no_content
  end

  test "rejects an inbound event without a link to the message" do
    body = lettermint_inbound_payload(recipient: "a@example.com", raw: nil)
    post rails_lettermint_inbound_emails_path, params: body, headers: lettermint_webhook_headers(body)
    assert_response :unprocessable_entity
  end

  test "keeps the message and its link out of the logs" do
    post rails_lettermint_inbound_emails_path, params: @body, headers: lettermint_webhook_headers(@body)
    assert_equal "[FILTERED]", request.filtered_parameters["data"]
    assert_equal "message.inbound", request.filtered_parameters["event"]
  end

  test "is not found unless Lettermint is the configured ingress" do
    with_ingress(:relay) do
      post rails_lettermint_inbound_emails_path, params: @body, headers: lettermint_webhook_headers(@body)
    end
    assert_response :not_found
  end

  test "fails loudly without a webhook secret" do
    secret = ENV.delete("LETTERMINT_WEBHOOK_SECRET")
    assert_raises(ArgumentError) do
      post rails_lettermint_inbound_emails_path, params: @body, headers: lettermint_webhook_headers(@body, secret: "whsec_test")
    end
  ensure
    ENV["LETTERMINT_WEBHOOK_SECRET"] = secret
  end

  private
    def with_ingress(ingress)
      previous, ActionMailbox.ingress = ActionMailbox.ingress, ingress
      yield
    ensure
      ActionMailbox.ingress = previous
    end
end
