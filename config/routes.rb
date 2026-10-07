Rails.application.routes.draw do
  if Telex.receiving?
    scope "/rails/action_mailbox", module: "action_mailbox/ingresses" do
      post "/lettermint/inbound_emails" => "lettermint/inbound_emails#create", as: :rails_lettermint_inbound_emails
    end
  end
end
