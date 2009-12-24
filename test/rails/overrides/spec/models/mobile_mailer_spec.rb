# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + '/../spec_helper'

describe MobileMailer do
  before(:each) do
    ActionMailer::Base.deliveries = []

    @to      = ["outer@jp.mobile", "outer1@jp.mobile"]
    @subject = "日本語題名"
    @text    = "日本語テキスト"
    @sjis_regexp = %r!=\?shift_jis\?B\?(.+)\?=!
    @jis_regexp  = %r!=\?iso-2022-jp\?B\?(.+)\?=!
  end

  describe "PC 宛に送るとき" do
    it "正常に送信できること" do
      to = "bill.gate@microsoft.com"
      MobileMailer.deliver_message(to, "題名", "本文")

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first
      email.to.include?(to).should be_true
    end
  end

  describe "docomo にメールを送るとき" do
    before(:each) do
      @to = "docomo@docomo.ne.jp"
    end

    it "subject/body が Shift-JIS になること" do
      MobileMailer.deliver_message(@to, @subject, @text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first

      # subject
      NKF.nkf("-w", email.subject).should == @subject

      # body
      email.body.should match(/For docomo/)
      email.quoted_body.should match(/#{NKF.nkf("-sWx", @text)}/)
    end

    it "数値参照の絵文字が変換されること" do
      emoji_subject = @subject + "&#xe676;"
      emoji_text = @text + "&#xe68b;"

      mail = MobileMailer.deliver_message(@to, emoji_subject, emoji_text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first
      email.body.should match(/For docomo/)

      # subject
      email.quoted_subject.match(@sjis_regexp)
      $1.unpack("m").first.unpack("H*").first.should match(/f8d7/)

      # body
      NKF.nkf("-wSx --no-cp932", email.quoted_body).should match(/#{@text}/)
      email.quoted_body.unpack("H*")[0].should match(/f8ec/)
    end

    it "半角カナがそのまま送信されること" do
      half_kana_subject = @subject + "ｹﾞｰﾑ"
      half_kana_text    = @text + "ﾌﾞｯｸ"

      mail = MobileMailer.deliver_message(@to, half_kana_subject, half_kana_text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first
      email.body.should match(/For docomo/)

      NKF.nkf("-wx", email.subject).should == @subject + "ｹﾞｰﾑ"
      email.body.should match(/#{@text + "ﾌﾞｯｸ"}/)
    end
  end

  describe "au にメールを送るとき" do
    before(:each) do
      @to = "au@ezweb.ne.jp"
    end

    it "subject/body が JIS になること" do
      mail = MobileMailer.deliver_message(@to, @subject, @text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first

      email.body.should match(/For au/)
      NKF.nkf('-Jw', email.quoted_body).should match(/#{@text}/)

      NKF.nkf('-w', email.subject).should == @subject
    end

    it "数値参照が絵文字に変換されること" do
      emoji_subject = @subject + "&#xe676;"
      emoji_text    = @text    + "&#xe68b;"

      mail = MobileMailer.deliver_message(@to, emoji_subject, emoji_text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first

      email.body.should match(/For au/)
      email.quoted_body.unpack("H*").first.should match(/7621/)

      email.quoted_subject.unpack("H*").first.should match(/765e/)
    end
  end

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
      email.quoted_subject.match(@sjis_regexp)
      $1.unpack("m").first.unpack("H*").first.should match(/f97c/)

      # body
      email.body.should match(/For softbank/)
      email.quoted_body.unpack("H*").first.should match(/f76a/)
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
      email.quoted_body.should match(/For vodafone/)

      NKF.nkf('-w', email.subject).should == @subject
    end

    it "body が JIS になること" do
      mail = MobileMailer.deliver_message(@to, @subject, @text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first
      email.quoted_body.should match(/For vodafone/)

      NKF.nkf('-w', email.quoted_body).should match(/#{@text}/)
    end

    it "数値参照が〓に変換されること" do
      emoji_subject = @subject + "&#xe676;"
      emoji_text    = @text    + "&#xe68b;"

      mail = MobileMailer.deliver_message(@to, emoji_subject, emoji_text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first

      email.body.should match(/For vodafone/)
      email.body.should match(/#{@text}〓/)

      NKF.nkf("-wJx", email.subject) == @subject + "〓"
    end
  end
end

describe MobileMailer, " mail address" do
  before(:each) do
    ActionMailer::Base.deliveries = []

    @subject = "日本語題名"
    @text    = "日本語テキスト"
  end

  it "ピリオドが3つ以上連続するアドレスが有効になること" do
    to = "ruby...rails@domomo-ezweb.ne.jp"
    MobileMailer.deliver_message(to, @subject, @text)

    emails = ActionMailer::Base.deliveries
    emails.size.should == 1
    emails.first.to.include?(to).should be_true
  end

  it "@マークの直前にピリオドあるアドレスが有効になること" do
    to = "ruby.rails.@domomo-ezweb.ne.jp"
    MobileMailer.deliver_message(to, @subject, @text)

    emails = ActionMailer::Base.deliveries
    emails.size.should == 1
    emails.first.to.include?(to).should be_true
  end
end

describe MobileMailer, "receiving" do
  describe "docomo からのメールを受信するとき" do
    before(:each) do
      @email = open(Rails.root + "spec/fixtures/mobile_mailer/docomo-emoji.eml").read
    end

    it "漢字コードを適切に変換できること" do
      email = MobileMailer.receive(@email)
      email.subject.should match(/題名/)
      email.body.should match(/本文/)
    end

    it "絵文字が数値参照に変わること" do
      email = MobileMailer.receive(@email)

      email.subject.should match(/&#xe676;/)
      email.body.should match(/&#xe6e2;/)
    end
  end

  # describe "au からのメールを受信するとき" do
  #   before(:each) do
  #     @email = open(Rails.root + "spec/fixtures/mobile_mailer/au-emoji.eml").read
  #   end

  #   it "漢字コードを適切に変換できること" do
  #     email = MobileMailer.receive(@email)

  #     email.subject.should match(/題名/)
  #     email.body.should match(/本文/)
  #   end

  #   it "絵文字が数値参照に変わること" do
  #     email = MobileMailer.receive(@email)

  #     email.subject.should match(/&#xe676;/)
  #     email.subject.should match(/&#xe6e2;/)
  #   end
  # end

  describe "softbank からのメールを受信するとき" do
    describe "shift_jis のとき" do
      before(:each) do
        @email = open(Rails.root + "spec/fixtures/mobile_mailer/softbank-emoji.eml").read
      end

      it "漢字コードを適切に変換できること" do
        email = MobileMailer.receive(@email)

        email.subject.should match(/題名/)
        email.body.should match(/本文/)
      end

      it "絵文字が数値参照に変わること" do
        email = MobileMailer.receive(@email)

        email.subject.should match(/&#xf03c;/)
        email.body.should match(/&#xf21c;/)
      end
    end

    describe "utf-8 のとき" do
      before(:each) do
        @email = open(Rails.root + "spec/fixtures/mobile_mailer/softbank-emoji-utf8.eml").read
      end

      it "漢字コードを適切に変換できること" do
        email = MobileMailer.receive(@email)

        email.subject.should match(/題名/)
        email.body.should match(/本文/)
      end

      it "絵文字が数値参照に変わること" do
        email = MobileMailer.receive(@email)

        email.subject.should match(/&#xf03c;/)
        email.body.should match(/&#xf21c;/)
      end
    end
  end
end
