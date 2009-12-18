# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + '/../spec_helper'

describe MobileMailer do
  before(:each) do
    ActionMailer::Base.deliveries = []

    @to      = ["outer@jp.mobile", "outer1@jp.mobile"]
    @subject = "日本語題名"
    @text    = "日本語テキスト"
  end

  # describe "docomo にメールを送るとき" do
  #   before(:each) do
  #     @to = "docomo@docomo.ne.jp"
  #   end

  #   it "subject/body が Shift-JIS になること" do
  #     MobileMailer.deliver_message(@to, @subject, @text)

  #     emails = ActionMailer::Base.deliveries
  #     emails.size.should == 1
  #     email = emails.first

  #     # subject
  #     NKF.nkf("-w", email.subject).should == @subject

  #     # body
  #     email.body.should match(/For docomo/)
  #     email.quoted_body.should match(/#{NKF.nkf("-sWx", @text)}/)
  #   end

  #   it "数値参照の絵文字が変換されること" do
  #     emoji_subject = @subject + "&#xe676;"
  #     emoji_text = @text + "&#xe68b;"

  #     mail = MobileMailer.deliver_message(@to, emoji_subject, emoji_text)

  #     emails = ActionMailer::Base.deliveries
  #     emails.size.should == 1
  #     email = emails.first
  #     email.body.should match(/For docomo/)

  #     # subject
  #     email.subject.unpack("H*")[0].should match(/f8d7/)

  #     # body
  #     NKF.nkf("-wSx --no-cp932", email.body).should match(/#{@text}/)
  #     email.body.unpack("H*")[0].should match(/f8ec/)
  #   end

  #   it "半角カナがそのまま送信されること" do
  #     half_kana_subject = @subject + "ｹﾞｰﾑ"
  #     half_kana_text    = @text + "ﾌﾞｯｸ"

  #     mail = MobileMailer.deliver_message(@to, half_kana_subject, half_kana_text)

  #     emails = ActionMailer::Base.deliveries
  #     emails.size.should == 1
  #     email = emails.first
  #     email.body.should match(/For docomo/)

  #     NKF.nkf("-wx", email.subject).should == @subject + "ｹﾞｰﾑ"
  #     email.body.should match(/#{@text + "ﾌﾞｯｸ"}/)
  #   end
  # end

  # describe "au にメールを送るとき" do
  #   before(:each) do
  #     @to = "au@ezweb.ne.jp"
  #   end

  #   it "subject が JIS になること" do
  #     mail = MobileMailer.deliver_message(@to, @subject, @text)

  #     emails = ActionMailer::Base.deliveries
  #     emails.size.should == 1
  #     email = emails.first
  #     email.body.should match(/For au/)

  #     NKF.nkf('-Jw', email.subject).should == @subject
  #   end

  #   it "数値参照が絵文字に変換されること" do
  #     emoji_subject = @subject + "&#xe676;"
  #     emoji_text    = @text    + "&#xe68b;"

  #     mail = MobileMailer.deliver_message(@to, emoji_subject, @text)

  #     emails = ActionMailer::Base.deliveries
  #     emails.size.should == 1
  #     email = emails.first
  #     email.body.should match(/For au/)

  #     email.subject.should == NKF.nkf("-jW", @subject) + ["f6dc"].pack("H*")
  #     NKF.nkf("-Swx", email.body).should match(/#{["f8ec"].pack("H*")}/)
  #   end
  # end

  describe "softbank にメールを送るとき" do
    before(:each) do
      @to = "softbank@softbank.ne.jp"
    end

    it "subject が Shift_JIS になること" do
      mail = MobileMailer.deliver_message(@to, @subject, @text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first
      email.body.should match(/For softbank/)

      NKF.nkf("-w", email.subject).should == @subject
    end

    it "body が Shift_JIS になること" do
      mail = MobileMailer.deliver_message(@to, @subject, @text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first
      email.body.should match(/For softbank/)

      email.body.should match(/For softbank/)
      email.quoted_body.should match(/#{NKF.nkf("-sWx", @text)}/)
    end

    it "数値参照が絵文字に変換されること" do
      emoji_subject = @subject + "&#xe676;"
      emoji_text    = @text    + "&#xe68a;"

      mail = MobileMailer.deliver_message(@to, emoji_subject, emoji_text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first

      # subject
      w = "G\\"
      email.subject.should match(/G\\/)

      # body
      email.body.should match(/For softbank/)
      w = 'EJ'
      email.body.should match(/EJ/)
    end
  end

  # describe "vodafone にメールを送るとき" do
  #   before(:each) do
  #     @to = "vodafone@d.vodafone.ne.jp"
  #   end

  #   it "subject が JIS になること" do
  #     mail = MobileMailer.deliver_message(@to, @subject, @text)

  #     emails = ActionMailer::Base.deliveries
  #     emails.size.should == 1
  #     email = emails.first
  #     email.quoted_body.should match(/For vodafone/)

  #     NKF.nkf('-w', email.subject).should == @subject
  #   end

  #   it "body が JIS になること" do
  #     mail = MobileMailer.deliver_message(@to, @subject, @text)

  #     emails = ActionMailer::Base.deliveries
  #     emails.size.should == 1
  #     email = emails.first
  #     email.quoted_body.should match(/For vodafone/)

  #     NKF.nkf('-w', email.quoted_body).should match(/#{@text}/)
  #   end

  #   it "数値参照が〓に変換されること" do
  #     emoji_subject = @subject + "&#xe676;"
  #     emoji_text    = @text    + "&#xe68b;"

  #     mail = MobileMailer.deliver_message(@to, emoji_subject, emoji_text)

  #     emails = ActionMailer::Base.deliveries
  #     emails.size.should == 1
  #     email = emails.first

  #     email.body.should match(/For vodafone/)
  #     email.body.should match(/#{@text}〓/)

  #     email.subject.should == @subject + "〓"
  #   end
  # end
end
