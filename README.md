# Telex

Email for our Rails apps through [Lettermint](https://lettermint.co), a Dutch provider with servers in the EU.

- **Sending:** a `:lettermint` delivery method for Action Mailer, over Lettermint's SMTP relay. Mailers, previews, `deliver_later` and gems that send mail (Devise…) work as usual.
- **Receiving:** a Lettermint ingress for Action Mailbox, next to the ones Rails ships for Postmark or Mailgun. Lettermint posts a signed webhook with a link to the original message; Telex checks the signature, downloads the message in a job and hands it to Action Mailbox, which routes it to the app's mailboxes.

Each app has its own Lettermint project: its own API token, logs, webhook and receiving subdomain (`reply.hq.box.paris`, `reply.ticket.box.paris`…).

## Install in an app

```ruby
# Gemfile
gem "telex"
```

Or `gem "telex", github: "boxprod/telex"` to follow `main` between releases.

```yaml
# bin/rails credentials:edit
lettermint:
  api_token: lm_...        # the project's API token, also the SMTP password
  webhook_secret: whsec_... # the inbound route's webhook secret, whsec_ included
```

Or `LETTERMINT_API_TOKEN` and `LETTERMINT_WEBHOOK_SECRET` in the environment.

### Sending

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :lettermint
```

The sending domain must be verified in the Lettermint project (SPF, DKIM, return path). Lettermint's [SMTP headers](https://lettermint.co/docs/guides/send-email-with-smtp) (`X-Lettermint-Route`, `X-LM-Tag`, `X-LM-Metadata-*`…) can be set in a mailer with `headers[...]`.

### Receiving

Install Action Mailbox if the app does not have it yet (it needs Active Storage):

```sh
bin/rails action_mailbox:install db:migrate
```

```ruby
# config/environments/production.rb
config.action_mailbox.ingress = :lettermint
```

In the Lettermint project, add an inbound route on the receiving subdomain (its MX records point to Lettermint) with the webhook

```
https://<the app>/rails/action_mailbox/lettermint/inbound_emails
```

Then route messages in `app/mailboxes/application_mailbox.rb` as with any Action Mailbox app. Inbound needs Lettermint's Starter plan or above.

What Telex adds to each message before Action Mailbox sees it:

| Header | |
|---|---|
| `X-Original-To` | The address it was delivered to, which Action Mailbox routes on even when it is not in To or Cc |
| `X-Lettermint-Spam` | `yes` or `no`, Lettermint's verdict; nothing is dropped |
| `X-Lettermint-Spam-Score` | Lettermint's score |

### How it behaves

- A wrong or missing signature, or one more than 5 minutes old, gets a `401`. Other events (deliveries, bounces) get a `204` and are ignored for now.
- The webhook answers once the download is queued. If the app cannot queue it, Lettermint gets a `500` and tries again.
- The job tries again for several hours when Lettermint cannot be reached, and gives up at once if the link has expired (28 days after the message arrived).
- A message that arrives twice is kept once: Action Mailbox ignores a source it already has.
- The links are secrets: the webhook's `data` is filtered from the request log and the job does not log its arguments.

## Testing in an app

To test a mailbox, Action Mailbox's own `receive_inbound_email_from_mail` is the simplest. To test the webhook end to end:

```ruby
require "telex/test_helper"

class InboundTest < ActionDispatch::IntegrationTest
  include Telex::TestHelper

  test "a reply reaches its quote" do
    body = lettermint_inbound_payload(recipient: "reply+quote-12@reply.hq.box.paris")
    post rails_lettermint_inbound_emails_path, params: body, headers: lettermint_webhook_headers(body)
    # Telex.download = an object answering #fetch(url) with the message's source, to run the job without the network
  end
end
```

## Not done yet

- Delivery events (bounces, complaints) are ignored. They would come through the same webhook.
- Whether Lettermint keeps the Message-ID Rails generates, which replies point to in `In-Reply-To`: Lettermint has an `X-LM-Preserve-Message-ID` header for it, to check against a real reply before relying on threading.

## Development

```sh
bundle install
bin/rails db:migrate
bin/rails test
```

To release, bump `lib/telex/version.rb`, commit, then `bundle exec rake release`: it tags, pushes the tag and pushes the gem to RubyGems, asking for a one-time code.
