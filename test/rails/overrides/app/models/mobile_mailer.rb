class MobileMailer < ActionMailer::Base
  def message(to_mail, subject_text, text, from_mail = "info@jp.mobile")
    recipients to_mail
    from       from_mail
    subject    subject_text
    body       :text => text
  end

  def receive(mail)
    email
  end
end
