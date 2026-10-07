module Telex
  # Downloads an inbound message and hands it to Action Mailbox. Lettermint retries webhooks,
  # and Action Mailbox ignores a message it already has, so running twice is harmless.
  #
  # Not the host's ApplicationJob: none of its callbacks or retries apply here.
  class IngestJob < ActiveJob::Base
    queue_as :default

    # The first argument is the signed link to the message.
    self.log_arguments = false

    retry_on Download::Error, wait: :polynomially_longer, attempts: 10

    discard_on Download::Gone do |job, error|
      Rails.logger.error "[Telex] Inbound email dropped: #{error.message} (job #{job.job_id})"
    end

    def perform(url, recipient: nil, spam_score: nil, spam: nil)
      source = Telex.download.fetch(url)
      ActionMailbox::InboundEmail.create_and_extract_message_id! headers(recipient, spam_score, spam) + source
    end

    private
      # The address the message was delivered to, which may not be in its To or Cc (a Bcc, a list),
      # is what Action Mailbox routes on. Lettermint's spam verdict comes along for mailboxes to use.
      def headers(recipient, spam_score, spam)
        lines = []
        lines << "X-Original-To: #{recipient}" if recipient.present?
        lines << "X-Lettermint-Spam: #{spam ? "yes" : "no"}" unless spam.nil?
        lines << "X-Lettermint-Spam-Score: #{spam_score}" unless spam_score.nil?
        lines.map { |line| "#{line}\r\n" }.join.b
      end
  end
end
