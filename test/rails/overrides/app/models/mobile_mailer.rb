class MobileMailer < ActionMailer::Base
  def message(to_mail, subject_text, text)
    recipients to_mail
    from       "info@jp.mobile"
    subject    subject_text
    body       :text => text
  end

  def recieve(mail)
  end
end
