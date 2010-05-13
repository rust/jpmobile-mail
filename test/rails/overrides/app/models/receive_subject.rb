class ReceiveSubject < ActionMailer::Base
  def receive(mail)
    mail.subject
  end
end
