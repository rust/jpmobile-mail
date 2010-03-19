class MobileMailer < ActionMailer::Base
  def message(to_mail, subject_text, text, from_mail = "info@jp.mobile")
    recipients to_mail
    from       from_mail
    subject    subject_text
    body       :text => text
  end

  def multi_message(to_mail, subject_text, html_text, plain_text, from_mail = "info@jp.mobile")
    recipients to_mail
    from       from_mail
    subject    subject_text

    part :content_type => "text/html", :body => render_message("multi_message", :text => html_text)

    part "text/plain" do |p|
      p.body = plain_text
    end
  end

  def receive(mail)
    mail
  end
end
