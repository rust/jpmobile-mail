# -*- coding: utf-8 -*-
# 絵文字と文字コードの変換処理
#   とりあえず1ファイルに書く

# 定数
Jpmobile::Emoticon::SEND_NKF_OPTIONS = {
  "shift_jis"   => "-sWx --no-cp932",
  "iso-2022-jp" => "-jW",
}
Jpmobile::Emoticon::RECEIVE_NKF_OPTIONS = {
  "shift_jis"   => "-wSx --no-cp932",
  "iso-2022-jp" => "-wJ",
  "euc-jp"      => "-wE",
  "utf-8"       => "-wW",
}

Jpmobile::Emoticon::SUBJECT_REGEXP = %r!=\?(shift[_-]jis|iso-2022-jp|euc-jp|utf-8)\?B\?(.+)\?=!i

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

    cattr_accessor :convert_pc_mail

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
          # 上記以外で convert_pc_mail が設定されていれば iso-2022-jp で送信する
          if @@convert_pc_mail
            @subject = NKF.nkf("-jW", @subject)
            @body    = NKF.nkf("-jW", @body)
            @charset = "iso-2022-jp"
          end
          @mobile = nil
        end
      elsif recipients.is_a?(Array)
        # 複数送信先の場合
        if @@convert_pc_mail
          @subject = NKF.nkf("-jW", @subject)
          @body    = NKF.nkf("-jW", @body)
          @charset = "iso-2022-jp"
        end
        @mobile = nil
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
          @nkf_opts    = Jpmobile::Emoticon::SEND_NKF_OPTIONS[@mail_encode]
          @mobile      = mobile
        end

        alias :encoded_without_jpmobile :encoded

        def encoded
          if @mobile
            jpm_subject = NKF.nkf(@nkf_opts, self.subject)
            jpm_subject = Jpmobile::Emoticon.unicodecr_to_email(jpm_subject, @mobile)
            jpm_subject = "=?#{@mail_encode}?B?" + [jpm_subject].pack("m").delete("\r\n") + "?="

            case @mobile
            when Jpmobile::Mobile::Au, Jpmobile::Mobile::Vodafone, Jpmobile::Mobile::Jphone
              jpm_body = self.quoted_body
              self.charset = @mail_encode

              # AU は iso-2022-jp なのでそのまま
              self.subject = jpm_subject
            else
              jpm_body = self.body
              self.charset = @mail_encode

              self.header["subject"].instance_variable_set(:@body, jpm_subject)
            end

            jpm_body = NKF.nkf(@nkf_opts, jpm_body)
            jpm_body = Jpmobile::Emoticon.unicodecr_to_email(jpm_body, @mobile)
            self.body    = jpm_body
          end

          encoded_without_jpmobile
        end
      end

      # 絵文字・漢字コード変換
      @mail.emoji_convert(@jpm_encode, @jpm_encode, @to_sjis, @mobile)

      @mail
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
          if subject.match(Jpmobile::Emoticon::SUBJECT_REGEXP)
            code    = $1
            subject = $2
          else
            code    = nil
          end

          # FIXME: 漢字コード決めうちなので汎用的な方法に変更
          case @mobile
          when Jpmobile::Mobile::Docomo
            # shift_jis コードであることが前提

            # subject の絵文字・漢字コード変換
            subject = Jpmobile::Emoticon.external_to_unicodecr_docomo(subject.unpack('m').first)
            @mail.subject = NKF.nkf(Jpmobile::Emoticon::RECEIVE_NKF_OPTIONS[code.downcase], subject)

            # body の絵文字・漢字コード変換
            body = Jpmobile::Emoticon.external_to_unicodecr_docomo(@mail.quoted_body)
            @mail.body = NKF.nkf(Jpmobile::Emoticon::RECEIVE_NKF_OPTIONS[@mail.charset], body)
          when Jpmobile::Mobile::Au
            # iso-2022-jp コードを変換

            # subject の絵文字・漢字コード変換
            subject = Jpmobile::Emoticon.external_to_unicodecr_au_mail(subject.unpack('m').first)
            @mail.subject = NKF.nkf(Jpmobile::Emoticon::RECEIVE_NKF_OPTIONS[code.downcase], subject)

            # body の絵文字・漢字コード変換
            # @mail.charset が iso-2022-jp なので無理に変換すると TMail 側で変換されてしまうので，漢字コードはそのまま
            body = Jpmobile::Emoticon.external_to_unicodecr_au_mail(@mail.quoted_body)
            @mail.body = body
          when Jpmobile::Mobile::Softbank
            case @mail.charset
            when /^shift_jis$/i
              # subject の絵文字・漢字コード変換
              # subject = Jpmobile::Emoticon.external_to_unicodecr_softbank(subject.unpack('m').first)
              subject = Jpmobile::Emoticon.external_to_unicodecr_softbank_sjis(subject.unpack('m').first)
              @mail.subject = NKF.nkf(Jpmobile::Emoticon::RECEIVE_NKF_OPTIONS[code.downcase], subject)

              # body の絵文字・漢字コード変換
              body = Jpmobile::Emoticon.external_to_unicodecr_softbank_sjis(@mail.quoted_body)
              @mail.body = NKF.nkf(Jpmobile::Emoticon::RECEIVE_NKF_OPTIONS[@mail.charset], body)
            when /^utf-8$/i
              # subject の絵文字・漢字コード変換
              # subject = Jpmobile::Emoticon.external_to_unicodecr_softbank(subject.unpack('m').first)
              subject = Jpmobile::Emoticon.external_to_unicodecr_softbank(subject.unpack('m').first)
              @mail.subject = NKF.nkf(Jpmobile::Emoticon::RECEIVE_NKF_OPTIONS[code.downcase], subject)

              # body の絵文字・漢字コード変換
              body = Jpmobile::Emoticon.external_to_unicodecr_softbank(@mail.quoted_body)
              @mail.body = NKF.nkf(Jpmobile::Emoticon::RECEIVE_NKF_OPTIONS[@mail.charset], body)
            else
              # 何もしない
            end
          end
        end

        @mail
      end
    end
  end
end
