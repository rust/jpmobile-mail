# -*- coding: utf-8 -*-
# 絵文字と文字コードの変換処理
#
module ActionMailer
  class Base
    @@default_charset = 'iso-2022-jp'

    WAVE_DASH = [0x301c].pack("U")
    FULLWIDTH_TILDA = [0xff5e].pack("U")

    # 暫定
    CONVERSION_TABLE_TO_PC = {}
    Jpmobile::Emoticon::CONVERSION_TABLE_TO_SOFTBANK.each{|k, v| CONVERSION_TABLE_TO_PC[k] = 0x3013}

    attr_accessor :mobile

    alias :create_without_jpmobile! :create!

    def create!(method_name, *parameters)
      create_without_jpmobile!(method_name, *parameters)

      # メールアドレスから判定
      if recipients.is_a?(String)
        mobile = Jpmobile::Email.detect(recipients)
      end

      return @mail unless mobile

      # 波ダッシュ問題の回避
      @mail.subject = @subject.gsub(FULLWIDTH_TILDA, WAVE_DASH)
      @mail.body = @mail.body.gsub(FULLWIDTH_TILDA, WAVE_DASH)

      # 数値参照に変換
      @mail.subject = Jpmobile::Emoticon::utf8_to_unicodecr(@mail.subject)
      @mail.body = Jpmobile::Emoticon::utf8_to_unicodecr(@mail.quoted_body)

      # 絵文字・漢字コード変換
      case mobile.new({})
      when Jpmobile::Mobile::Docomo
        # Shift_JIS に変換
        @mail.charset = "shift_jis"
        @mail.subject = NKF.nkf("-sWx", @mail.subject)
        @mail.body = NKF.nkf("-sWx", @mail.body)

        table = Jpmobile::Emoticon::CONVERSION_TABLE_TO_DOCOMO
        to_sjis = true

        @mail.subject = Jpmobile::Emoticon.unicodecr_to_external(@mail.subject, table, to_sjis)
        @mail.body = Jpmobile::Emoticon.unicodecr_to_external(@mail.body, table, to_sjis)
      when Jpmobile::Mobile::Au
        # iso-2022-jp に変換
        @mail.charset = "iso-2022-jp"
        @mail.subject = NKF.nkf("-jW", @mail.subject)
        @mail.body = NKF.nkf("-jW", @mail.quoted_body)

        table = Jpmobile::Emoticon::CONVERSION_TABLE_TO_AU
        to_sjis = false

        @mail.subject = Jpmobile::Emoticon.unicodecr_to_external(@mail.subject, table, to_sjis)
        @mail.body = Jpmobile::Emoticon.unicodecr_to_external(@mail.body, table, to_sjis)
      when Jpmobile::Mobile::Vodafone, Jpmobile::Mobile::Jphone
        # iso-2022-jp に変換
        @mail.charset = "iso-2022-jp"
        @mail.subject = NKF.nkf("-jW", @mail.subject)
        @mail.body = NKF.nkf("-jW", @mail.quoted_body)

        table = CONVERSION_TABLE_TO_PC
        to_sjis = false

        @mail.subject = Jpmobile::Emoticon.unicodecr_to_external(@mail.subject, table, to_sjis)
        @mail.body = Jpmobile::Emoticon.unicodecr_to_external(@mail.body, table, to_sjis)
      when Jpmobile::Mobile::Softbank
        # shift_jis に変換
        @mail.charset = "shift_jis"
        @mail.subject = NKF.nkf("-sWx", @mail.subject)
        @mail.body = NKF.nkf("-sWx", @mail.quoted_body)

        table = Jpmobile::Emoticon::CONVERSION_TABLE_TO_SOFTBANK
        to_sjis = false

        @mail.subject = Jpmobile::Emoticon.unicodecr_to_external(@mail.subject, table, to_sjis)
        @mail.body = Jpmobile::Emoticon.unicodecr_to_external(@mail.body, table, to_sjis)
      else
        # iso-2022-jp に変換
        @mail.charset = "iso-2022-jp"
        @mail.subject = NKF.nkf("-jW", @mail.subject)
        @mail.body = NKF.nkf("-jW", @mail.quoted_body)
      end

      @mail
    end
  end
end
