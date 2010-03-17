class ReceiveBody < ActionMailer::Base
  def receive(mail)
    mail.body
  end
end
