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

    it "設定(pc_convert)によって jis に変換されること" do
      to = "bill.gate@microsoft.com"
      ActionMailer::Base.pc_convert = true
      MobileMailer.deliver_message(to, "題名", "本文")

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first

      email.quoted_subject.should match(/#{Regexp.escape(NKF.nkf("-jWM", "題名"))}/i)
      email.quoted_body.should match(/#{Regexp.escape(NKF.nkf("-jW", "本文"))}/)
    end

    it "絵文字がゲタ(〓)に変換されること" do
      to = "bill.gate@microsoft.com"
      ActionMailer::Base.pc_convert = true
      MobileMailer.deliver_message(to, "題名&#xe676;", "本文&#xe68b;")

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first

      NKF.nkf("-m", email.quoted_subject).should == NKF.nkf("-m", "題名〓")
      NKF.nkf("-Jw", email.quoted_body).should match(/〓/)
    end

    it "通常は utf-8 になること" do
      to = "bill.gate@microsoft.com"
      ActionMailer::Base.pc_convert = nil
      MobileMailer.deliver_message(to, "題名", "本文")

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first

      email.subject.should == "題名"
      email.body.should match(/本文/)
    end

    it "複数に配信するときも，設定によって jis に変換されること" do
      ActionMailer::Base.pc_convert = true
      MobileMailer.deliver_message(@to, "題名", "本文")

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first

      email.quoted_subject.should match(/#{Regexp.escape(NKF.nkf("-jWM", "題名"))}/i)
      email.quoted_body.should match(/#{Regexp.escape(NKF.nkf("-jW", "本文"))}/)
    end

    it "複数に配信するときも，通常は utf-8 になること" do
      ActionMailer::Base.pc_convert = nil
      MobileMailer.deliver_message(@to, "題名", "本文")

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first

      email.subject.should == "題名"
      email.body.should match(/本文/)
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

      email.subject.should == @subject + "ｹﾞｰﾑ"
      email.body.should match(Regexp.compile(Regexp.escape(NKF.nkf("-sWx", @text + "ﾌﾞｯｸ"), 's'), nil, 's'))
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

    it "subject/body が Shift_JIS になること" do
      mail = MobileMailer.deliver_message(@to, @subject, @text)

      emails = ActionMailer::Base.deliveries
      emails.size.should == 1
      email = emails.first
      email.body.should match(/For softbank/)

      email.quoted_subject.match(@sjis_regexp)
      $1.unpack("m").first.should == NKF.nkf("-sW", @subject)

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
      NKF.nkf("-wJx", email.body).should match(/#{@text}〓/)

      NKF.nkf("-wJx", email.subject) == @subject + "〓"
    end
  end

  describe "multipart メールを送信するとき" do
    before(:each) do
      ActionMailer::Base.deliveries = []
      ActionMailer::Base.pc_convert = nil

      @subject = "題名"
      @plain   = "平文本文"
      @html    = "html本文"
      @from    = "info@jpmobile-rails.org"
    end

    describe "PC の場合" do
      before(:each) do
        @to = "gate@bill.com"
      end

      it "漢字コードが変換されること" do
        ActionMailer::Base.pc_convert = true
        MobileMailer.deliver_multi_message(@to, @subject, @html, @plain, @from)

        emails = ActionMailer::Base.deliveries
        emails.size.should == 1
        email = emails.first

        email.parts.size.should == 2
        NKF.nkf("-mQ", email.parts.first.quoted_body).should match(/#{Regexp.escape(NKF.nkf("-jWx", "万葉"))}/)
        email.parts.last.quoted_body.should match(/#{Regexp.escape(NKF.nkf("-jWx", @plain))}/)
      end
    end

    describe "docomo の場合" do
      before(:each) do
        @to     = "docomo@docomo.ne.jp"
      end

      it "漢字コードが変換されること" do
        MobileMailer.deliver_multi_message(@to, @subject, @html, @plain, @from)

        emails = ActionMailer::Base.deliveries
        emails.size.should == 1
        email = emails.first

        email.parts.size.should == 2
        email.parts.first.quoted_body.unpack("m").first.should match(Regexp.compile(Regexp.escape(NKF.nkf("-sWx", @html), 's'), nil, 's'))
        email.parts.last.quoted_body.should match(/#{Regexp.escape(NKF.nkf("-sWx", @plain))}/)
      end

      it "絵文字が変換されること" do
        @html  += "&#xe68b;"
        @plain += "&#xe676;"
        MobileMailer.deliver_multi_message(@to, @subject, @html, @plain, @from)

        emails = ActionMailer::Base.deliveries
        emails.size.should == 1
        email = emails.first

        email.parts.size.should == 2
        email.parts.first.quoted_body.unpack("m").first.should match(Regexp.compile(Regexp.escape([0xf8ec].pack('n'), 's'), nil, 's'))
        email.parts.last.quoted_body.should match(Regexp.compile(Regexp.escape([0xf8d7].pack('n'), 's'), nil, 's'))
      end
    end

    describe "au の場合" do
      before(:each) do
        @to     = "au@ezweb.ne.jp"
      end

      it "漢字コードが変換されること" do
        MobileMailer.deliver_multi_message(@to, @subject, @html, @plain, @from)

        emails = ActionMailer::Base.deliveries
        emails.size.should == 1
        email = emails.first

        email.parts.size.should == 2

        NKF.nkf("-mQ", email.parts.first.quoted_body).should match(/#{Regexp.escape(NKF.nkf("-jWx", @html))}/)
        email.parts.last.quoted_body.should match(/#{Regexp.escape(NKF.nkf("-jWx", @plain))}/)
      end

      it "絵文字が変換されること" do
        @plain += "&#xe676;"
        @html  += "&#xe68b;"
        MobileMailer.deliver_multi_message(@to, @subject, @html, @plain, @from)

        emails = ActionMailer::Base.deliveries
        emails.size.should == 1
        email = emails.first

        email.parts.size.should == 2

        NKF.nkf("-mQ", email.parts.first.quoted_body).should match(/#{Regexp.escape([0x7621].pack('n'))}/)
        email.parts.last.quoted_body.should match(/#{Regexp.escape([0x765e].pack('n'))}/)
      end
    end

    # describe "softbank の場合" do
    #   before(:each) do
    #     @to     = "softbank@softbank.ne.jp"
    #   end

    #   it "漢字コードが変換されること" do
    #     MobileMailer.deliver_multi_message(@to, @subject, @html, @plain, @from)

    #     emails = ActionMailer::Base.deliveries
    #     emails.size.should == 1
    #     email = emails.first

    #     email.parts.size.should == 2
    #     email.parts.first.quoted_body.unpack("m").first.should match(Regexp.compile(Regexp.escape(NKF.nkf("-sWx", @html), 's'), nil, 's'))
    #     email.parts.last.quoted_body.should match(/#{Regexp.escape(NKF.nkf("-sWx", @plain))}/)
    #   end

    #   it "絵文字が変換されること" do
    #     @html  += "&#xe68b;"
    #     @plain += "&#xe676;"
    #     MobileMailer.deliver_multi_message(@to, @subject, @html, @plain, @from)

    #     emails = ActionMailer::Base.deliveries
    #     emails.size.should == 1
    #     email = emails.first

    #     email.parts.size.should == 2
    #     email.parts.first.quoted_body.unpack("m").first.should match(Regexp.compile(Regexp.escape([0xf8ec].pack('n'), 's'), nil, 's'))
    #     email.parts.last.quoted_body.should match(Regexp.compile(Regexp.escape([0xf8d7].pack('n'), 's'), nil, 's'))
    #   end
    # end
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
    emails.first.destinations.include?(to).should be_true
  end

  it "@マークの直前にピリオドあるアドレスが有効になること" do
    to = "ruby.rails.@domomo-ezweb.ne.jp"
    MobileMailer.deliver_message(to, @subject, @text)

    emails = ActionMailer::Base.deliveries
    emails.size.should == 1
    emails.first.to.include?(to).should be_true
    emails.first.destinations.include?(to).should be_true
  end

  it "ピリオドから始まるアドレスが有効になること" do
    to = ".ruby.rails.@domomo-ezweb.ne.jp"
    MobileMailer.deliver_message(to, @subject, @text)

    emails = ActionMailer::Base.deliveries
    emails.size.should == 1
    emails.first.to.include?(to).should be_true
    emails.first.destinations.include?(to).should be_true
  end

  it "複数のアドレスが有効になること" do
    to = [".ruby.rails.@domomo-ezweb.ne.jp", "ruby.rails.@domomo-ezweb.ne.jp", "ruby...rails@domomo-ezweb.ne.jp"]
    MobileMailer.deliver_message(to, @subject, @text)

    emails = ActionMailer::Base.deliveries
    emails.size.should == 1
    emails.first.to.should == to
    emails.first.destinations.should == to
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

    describe "jis コードの場合に" do
      before(:each) do
        @email = open(Rails.root + "spec/fixtures/mobile_mailer/docomo-jis.eml").read
      end

      it "適切に変換できること" do
        email = MobileMailer.receive(@email)

        email.subject.should match(/テスト/)
        email.body.should match(/テスト本文/)
      end
    end
  end

  describe "au からのメールを受信するとき" do
    describe "jpmobile で送信したメールの場合" do
      before(:each) do
        @email = open(Rails.root + "spec/fixtures/mobile_mailer/au-emoji.eml").read
      end

      it "漢字コードを適切に変換できること" do
        email = MobileMailer.receive(@email)

        email.subject.should match(/題名/)
        email.body.should match(/本文/)
      end

      it "絵文字が数値参照に変わること" do
        email = MobileMailer.receive(@email)

        email.subject.should match(/&#xe503;/)
        email.body.should match(/&#xe522;/)
      end
    end

    describe "実機からのメールの場合" do
      before(:each) do
        @email = open(Rails.root + "spec/fixtures/mobile_mailer/au-emoji2.eml").read
      end

      it "漢字コードを適切に変換できること" do
        email = MobileMailer.receive(@email)

        email.subject.should match(/題名/)
        email.body.should match(/本文/)
      end

      it "絵文字が数値参照に変わること" do
        email = MobileMailer.receive(@email)

        email.subject.should match(/&#xe4f4;/)
        email.body.should match(/&#xe471;/)
      end
    end
  end

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

  # describe "multipart メールを受信するとき" do
  #   describe "au の場合" do
  #     before(:each) do
  #       @email = open(Rails.root + "spec/fixtures/mobile_mailer/au-attached.eml").read
  #     end

  #     it "正常に受信できること" do
  #       lambda {
  #         MobileMailer.receive(@email)
  #       }.should_not raise_exception
  #     end

  #     it "絵文字が変換されること" do
  #       email = MobileMailer.receive(@email)

  #       email.subject.should match(/&#xe481;/)
  #       email.body.should match(/&#xe4f4;/)
  #     end
  #   end
  # end
end





