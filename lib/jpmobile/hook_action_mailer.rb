# -*- coding: utf-8 -*-
# 絵文字と文字コードの変換処理
#   とりあえず1ファイルに書く

# convert_to で機種依存文字や絵文字に対応するために
# Unquoter 内で NKF を使用するようにしたもの
module TMail
  class UnstructuredHeader
    def parsed
      @parsed = true
    end

    def not_parsed
      @parsed = false
    end

    private
    alias :parse_without_jpmobile :parse

    def parse
      @body = Decoder.decode(@body.gsub(/\n|\r\n|\r/, ''))
    end
  end

  class Unquoter
    class << self
      # http://www.kbmj.com/~shinya/rails_seminar/slides/#(30)
      def convert_to_with_nkf(text, to, from)
        if text && to =~ /^utf-8$/i && from =~ /^iso-2022-jp$/i
          NKF.nkf("-Jw", text)
        elsif text && from =~ /^utf-8$/i && to =~ /^iso-2022-jp$/i
          NKF.nkf("-Wj", text)
        else
          convert_to_without_nkf(text, to, from)
        end
      end

      alias_method_chain :convert_to, :nkf
    end
  end

  class Decoder
    OUTPUT_ENCODING["SJIS-MOBILE"] = "sx"

    self.instance_eval do
      alias :decode_without_jpmobile :decode
    end

    def self.decode( str, encoding = nil )
      # shift_jis の場合のみ半角カナを許可する
      if str =~ %r!=\?shift_jis\?B\?([A-Za-z0-9\+/=]+)\?=! and $1
        return NKF.nkf("-mBwx", $1)
      end

      decode_without_jpmobile(str, encoding)
    end
  end
end

module ActionMailer
  class Base
    # for ActionMailer::Quoting
    alias :quoted_printable_without_jpmobile :quoted_printable

    def quoted_printable(text, charset)
      # 携帯で shift_jis エンコードなら Base64 でパックする
      if @mobile and @charset == "shift_jis"
        # "=?shift_jis?B?" + NKF.nkf("-MB", text) + "?="
        NKF.nkf("-sWxMB", text)
      else
        quoted_printable_without_jpmobile(text, charset)
      end
    end

    @@default_charset = 'iso-2022-jp'
    @@encode_subject = false

    WAVE_DASH = [0x301c].pack("U")
    FULLWIDTH_TILDA = [0xff5e].pack("U")

    # 暫定
    CONVERSION_TABLE_TO_PC = {}
    Jpmobile::Emoticon::CONVERSION_TABLE_TO_SOFTBANK.each{|k, v| CONVERSION_TABLE_TO_PC[k] = 0x3013}

    alias :create_without_jpmobile! :create!
    alias :create_mail_without_jpmobile :create_mail

    def create_mail
      # メールアドレスから判定
      if recipients.is_a?(String)
        @mobile = Jpmobile::Email.detect(recipients).new({})

        # 波ダッシュ問題の回避
        @subject = @subject.gsub(FULLWIDTH_TILDA, WAVE_DASH)
        @body = @body.gsub(FULLWIDTH_TILDA, WAVE_DASH)

        # 数値参照に変換
        @subject = Jpmobile::Emoticon::utf8_to_unicodecr(@subject)
        @body = Jpmobile::Emoticon::utf8_to_unicodecr(@body)

        case @mobile
        when Jpmobile::Mobile::Docomo
          @table = Jpmobile::Emoticon::CONVERSION_TABLE_TO_DOCOMO
          @to_sjis = true
          # Shift_JIS に変換
          @charset = "shift_jis"

          # 絵文字・漢字コード変換
          @jpmobile_subject = "=?shift_jis?B?" + [@subject].pack("m").delete("\r\n") + "?="
          @jpmobile_subject = NKF.nkf("-sWx", @jpmobile_subject)
          @jpmobile_subject = Jpmobile::Emoticon.unicodecr_to_external(@jpmobile_subject, @table, @to_sjis)

          # 本文変換
          @jpmobile_body = NKF.nkf("-sWx", @body)
          @jpmobile_body = Jpmobile::Emoticon.unicodecr_to_external(@jpmobile_body, @table, @to_sjis)
        when Jpmobile::Mobile::Au
          @table = Jpmobile::Emoticon::CONVERSION_TABLE_TO_AU
          @to_sjis = false
        when Jpmobile::Mobile::Vodafone, Jpmobile::Mobile::Jphone
          @table = CONVERSION_TABLE_TO_PC # ゲタに変換する
          @to_sjis = false
        when Jpmobile::Mobile::Softbank
          @table = Jpmobile::Emoticon::CONVERSION_TABLE_TO_SOFTBANK
          @to_sjis = true
          @charset = "shift_jis"
        else
          @table = CONVERSION_TABLE_TO_PC # ゲタに変換する
          @to_sjis = false
        end
      end

      create_mail_without_jpmobile
    end

    def create!(method_name, *parameters)
      create_without_jpmobile!(method_name, *parameters)

      return @mail unless @mobile

      # 絵文字・漢字コード変換
      case @mobile
      when Jpmobile::Mobile::Docomo
        # body を代入する
        @mail.body = @jpmobile_body

        # Subject: に直接代入する
        @mail.header["subject"].parsed
        @mail.header["subject"].body = "=?shift_jis?B?" + [@jpmobile_subject].pack("m").delete("\r\n") + "?="
      when Jpmobile::Mobile::Au
        # iso-2022-jp に変換
        @mail.charset = "iso-2022-jp"

        @mail.subject = NKF.nkf("-jW", @mail.subject)
        @mail.subject = Jpmobile::Emoticon.unicodecr_to_external(@mail.subject, @table, @to_sjis)
        @mail.subject = "=?ISO-2022-JP?B?" + [@mail.subject].pack("m").delete("\r\n") + "?="

        @mail.body = NKF.nkf("-jW", @mail.quoted_body)
        @mail.body = Jpmobile::Emoticon.unicodecr_to_external(@mail.body, @table, @to_sjis)
      when Jpmobile::Mobile::Vodafone, Jpmobile::Mobile::Jphone
        # iso-2022-jp に変換
        @mail.charset = "iso-2022-jp"

        @mail.subject = NKF.nkf("-jW", @mail.subject)
        @mail.subject = Jpmobile::Emoticon.unicodecr_to_external(@mail.subject, @table, @to_sjis)
        @mail.subject = "=?ISO-2022-JP?B?" + [@mail.subject].pack("m").delete("\r\n") + "?="

        @mail.body = NKF.nkf("-jW", @mail.quoted_body)
        @mail.body = Jpmobile::Emoticon.unicodecr_to_external(@mail.quoted_body, @table, @to_sjis)
      when Jpmobile::Mobile::Softbank
        # shift_jis に変換
        @mail.charset = "shift_jis"
# Tmail::Mail::Unquoter.unquote_and_convert_to で "=?shift_jis?B? ... ?=" などが外されるので，
# それを受けて次の encoded に入る際にどうやら再度 @@default_charset で encode される模様
# Tmail なのか ActionMailer なのかちゃんと判断しないといけない
require 'pp'
pp "\n"
pp @mail.encoded
pp "before"
        @mail.subject = NKF.nkf("-sWx", @mail.subject)
pp "translated"
pp @mail.quoted_subject
pp @mail.encoded
        @mail.subject = Jpmobile::Emoticon.unicodecr_to_external(@mail.subject, @table, @to_sjis)
pp "convert-emoticon"
pp @mail.quoted_subject
pp @mail.encoded
        @mail.subject = "=?shift_jis?B?" + [@mail.subject].pack("m").delete("\r\n") + "?="
pp "encode-subject"
pp @mail.quoted_subject
pp @mail.encoded
pp @mail.class
pp "after"

        @mail.body = NKF.nkf("-sWx", @mail.quoted_body)
        @mail.body = Jpmobile::Emoticon.unicodecr_to_external(@mail.quoted_body, @table, @to_sjis)
pp "body"
pp @mail.encoded
pp "----"
      else
        # iso-2022-jp に変換
        @mail.charset = "iso-2022-jp"

        @mail.subject = NKF.nkf("-jW", @mail.subject)
        @mail.subject = Jpmobile::Emoticon.unicodecr_to_external(@mail.subject, @table, @to_sjis)
        @mail.subject = "=?ISO-2022-JP?B?" + [@mail.subject].pack("m").delete("\r\n") + "?="

        @mail.body = NKF.nkf("-jW", @mail.quoted_body)
        @mail.body = Jpmobile::Emoticon.unicodecr_to_external(@mail.body, @table, @to_sjis)
      end

      @mail
    end

    alias :deliver_without_jpmobile! :deliver!

    def deliver!(mail = @mail)
      r = deliver_without_jpmobile!(mail)

#       @mail.header["subject"].not_parsed
# p @mail.object_id
      r
    end
  end
end
