# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + '/../spec_helper'

describe MobileMailer do
  before(:each) do
    ActionMailer::Base.deliveries = []

    @to      = ["outer@jp.mobile", "outer1@jp.mobile"]
    @subject = "日本語題名"
    @text    = "日本語テキスト"
  end

  it "should send a email" do
    MobileMailer.deliver_message(@to, @subject, @text)

    emails = ActionMailer::Base.deliveries
    emails.size.should == 1
    email = emails.first
    email.body.should match(/For PC/)
  end

  describe "docomo にメールを送るとき" do
    before(:each) do
      @to = "docomo@docomo.ne.jp"
    end

    it "subject が Shift-JIS になること" do
      mail = MobileMailer.deliver_message(@to, @subject, @text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first

      email.body.should match(/For docomo/)
      NKF.nkf('-Sw', email.subject).should == @subject
    end

    it "数値参照の絵文字が変換されること" do
      emoji_subject = @subject + "&#xe676;"

      mail = MobileMailer.deliver_message(@to, emoji_subject, @text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first

      email.body.should match(/For docomo/)
      email.subject.should == NKF.nkf("-sW", @subject) + ["f8d7"].pack("H*");
    end
  end

  describe "au にメールを送るとき" do
    before(:each) do
      @to = "au@ezweb.ne.jp"
    end

    it "subject が JIS になること" do
      mail = MobileMailer.deliver_message(@to, @subject, @text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first

      email.body.should match(/For au/)
      NKF.nkf('-Jw', email.subject).should == @subject
    end

    it "数値参照が絵文字に変換されること" do
      emoji_subject = @subject + "&#xe676;"

      mail = MobileMailer.deliver_message(@to, emoji_subject, @text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first

      email.body.should match(/For au/)
      email.subject.should == NKF.nkf("-jW", @subject) + ["f6dc"].pack("H*")
    end
  end

  describe "softbank にメールを送るとき" do
    before(:each) do
      @to = "softbank@softbank.ne.jp"
    end

    it "subject が JIS になること" do
      mail = MobileMailer.deliver_message(@to, @subject, @text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first

      email.body.should match(/For softbank/)
      NKF.nkf('-Jw', email.subject).should == @subject
    end

    it "数値参照が絵文字に変換されること" do
      emoji_subject = @subject + "&#xe676;"

      mail = MobileMailer.deliver_message(@to, emoji_subject, @text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first

p email.subject.unpack("H*")
p (@subject + ["e03c"].pack("H*")).unpack("H*")
      email.body.should match(/For softbank/)
      email.subject.should == NKF.nkf("-sWx", @subject) + ["e03c"].pack("H*")
    end
  end

  describe "vodafone にメールを送るとき" do
    before(:each) do
      @to = "vodafone@d.vodafone.ne.jp"
    end

    it "subject が JIS になること" do
      mail = MobileMailer.deliver_message(@to, @subject, @text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first

      email.body.should match(/For vodafone/)
      NKF.nkf('-Jw', email.subject).should == @subject
    end

    it "数値参照が〓に変換されること" do
      emoji_subject = @subject + "&#xe676;"

      mail = MobileMailer.deliver_message(@to, emoji_subject, @text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first

      email.body.should match(/For vodafone/)
      NKF.nkf("-Jw", email.subject).should == @subject + "〓"
    end
  end
end
