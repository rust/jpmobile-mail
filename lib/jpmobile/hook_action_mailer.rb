# -*- coding: utf-8 -*-
# 絵文字と文字コードの変換処理
#   とりあえず1ファイルに書く

# 定数
Jpmobile::Emoticon::NKF_OPTIONS = {
  "shift_jis"   => "-sWx --no-cp932",
  "iso-2022-jp" => "-jW",
}
encoded = '=\?(?:iso-2022-jp|euc-jp|shift_jis)\?[QB]\?[a-z0-9+/=]+\?='
ENCODED_WORDS = /#{encoded}((?:\s+#{encoded}))*/i

Jpmobile::Emoticon::SJIS_SUBJECT_REGEXP = %r!=\?shift_jis\?B\?([a-z0-9+\/=]+)\?=!i
Jpmobile::Emoticon::JIS_SUBJECT_REGEXP  = %r!=\?iso-2022-jp\?B\?(.+)\?=!i

# convert_to で機種依存文字や絵文字に対応するために
# Unquoter 内で NKF を使用するようにしたもの
module TMail
  class Unquoter
    class << self
      # http://www.kbmj.com/~shinya/rails_seminar/slides/#(30)
      def convert_to_with_nkf(text, to, from)
        if text and to =~ /^utf-8$/i and from =~ /^iso-2022-jp$/i
          NKF.nkf("-Jw", text)
        elsif text and from =~ /^utf-8$/i and to =~ /^iso-2022-jp$/i
          NKF.nkf("-Wj", text)
        else
          if from =~ /^shift_jis$/i
            convert_to_without_nkf(text, to, "cp932")
          else
            convert_to_without_nkf(text, to, from)
          end
        end
      end

      alias_method_chain :convert_to, :nkf
    end
  end
end

module ActionMailer
  class Base
    WAVE_DASH = [0x301c].pack("U")
    FULLWIDTH_TILDA = [0xff5e].pack("U")

    alias :create_without_jpmobile! :create!
    alias :create_mail_without_jpmobile :create_mail

    def create_mail
      # メールアドレスから判定
      if recipients.is_a?(String)
        @mobile = Jpmobile::Email.detect(recipients).new({}) rescue nil

        # 波ダッシュ問題の回避
        @subject = @subject.gsub(FULLWIDTH_TILDA, WAVE_DASH)
        @body = @body.gsub(FULLWIDTH_TILDA, WAVE_DASH)

        # 数値参照に変換
        @subject = Jpmobile::Emoticon::utf8_to_unicodecr(@subject)
        @body = Jpmobile::Emoticon::utf8_to_unicodecr(@body)

        case @mobile
        when Jpmobile::Mobile::Docomo
          @jpm_encode = "shift_jis"
          @to_sjis    = true
        when Jpmobile::Mobile::Au
          @jpm_encode = "iso-2022-jp"
          @to_sjis    = false
        when Jpmobile::Mobile::Vodafone, Jpmobile::Mobile::Jphone
          @jpm_encode = "iso-2022-jp"
          @to_sjis    = false
        when Jpmobile::Mobile::Softbank
          @jpm_encode = "shift_jis"
          @to_sjis    = true
        else
          # 上記以外は iso-2022-jp で送信する
          @charset = "iso-2022-jp"
          @mobile = nil
        end
      end

      create_mail_without_jpmobile
    end

    def create!(method_name, *parameters)
      create_without_jpmobile!(method_name, *parameters)

      return @mail unless @mobile

      # TMail::Mail の encoded を hook する
      @mail.instance_eval do
        def emoji_convert(mail_encode, body_encode, to_sjis, mobile = nil)
          @mail_encode = mail_encode
          @emoji_sjis  = to_sjis
          @nkf_opts    = Jpmobile::Emoticon::NKF_OPTIONS[@mail_encode]
          @mobile      = mobile
        end

        alias :encoded_without_jpmobile :encoded

        def encoded
          if @mobile
            @jpm_subject = NKF.nkf(@nkf_opts, self.subject)
            @jpm_subject = Jpmobile::Emoticon.unicodecr_to_email(@jpm_subject, @mobile)
            @jpm_subject = "=?#{@mail_encode}?B?" + [@jpm_subject].pack("m").delete("\r\n") + "?="

            case @mobile
            when Jpmobile::Mobile::Au, Jpmobile::Mobile::Vodafone, Jpmobile::Mobile::Jphone
              @jpm_body = self.quoted_body
              self.charset = @mail_encode

              # AU は iso-2022-jp なのでそのまま
              self.subject = @jpm_subject
            else
              @jpm_body = self.body
              self.charset = @mail_encode

              self.header["subject"].instance_variable_set(:@body, @jpm_subject)
            end

            @jpm_body = NKF.nkf(@nkf_opts, @jpm_body)
            @jpm_body = Jpmobile::Emoticon.unicodecr_to_email(@jpm_body, @mobile)
            self.body    = @jpm_body
          end

          encoded_without_jpmobile
        end
      end

      # 絵文字・漢字コード変換
      @mail.emoji_convert(@jpm_encode, @jpm_encode, @to_sjis, @mobile)

      @mail
    end

    # deliver
    alias :deliver_without_jpmobile! :deliver!

    def deliver!(mail = @mail)
      r = deliver_without_jpmobile!(mail)
      r
    end

    # receive
    class << self
      alias :receive_without_jpmobile :receive

      def receive(raw_mail)
        @raw_data = raw_mail
        @mail     = receive_without_jpmobile(raw_mail)

        # 携帯かどうか判定
        if (@mobile = Jpmobile::Email.detect(@mail.from.first).new({}) rescue nil)
          # 携帯であれば subject は @header から直接取得して変換する
          header = @mail.instance_variable_get(:@header)
          subject = header["subject"].instance_variable_get(:@body)

          # FIXME: 漢字コード決めうちなので汎用的な方法に変更
          case @mobile
          when Jpmobile::Mobile::Docomo
            # subject の絵文字・漢字コード変換
            subject = $1.unpack('m').first if subject.match(Jpmobile::Emoticon::SJIS_SUBJECT_REGEXP)
            subject = Jpmobile::Emoticon.external_to_unicodecr_docomo(subject)
            @mail.subject = NKF.nkf("-wSx", subject)

            # body の絵文字・漢字コード変換
            body = Jpmobile::Emoticon.external_to_unicodecr_docomo(@mail.quoted_body)
            @mail.body = NKF.nkf("-wSx", body)
          when Jpmobile::Mobile::Au
          when Jpmobile::Mobile::Softbank
          end
        end

        @mail
      end
    end
  end
end
