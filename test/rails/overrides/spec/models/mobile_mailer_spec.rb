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
      MobileMailer.deliver_message(@to, @subject, @text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first

      email.body.should match(/For docomo/)
      NKF.nkf('-Jw', email.subject).should == @subject
    end
  end

  describe "au にメールを送るとき" do

  end

  describe "softbank にメールを送るとき" do

  end

  describe "Willcom へメールを送るとき" do

  end
end
