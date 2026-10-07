class NoticeMailer < ApplicationMailer
  def hello
    mail to: "ana@example.com", subject: "Hello", body: "Hello"
  end
end
