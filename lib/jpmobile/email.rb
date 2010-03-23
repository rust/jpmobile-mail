# -*- coding: utf-8 -*-
# =メール用モジュール
#
module Jpmobile
  # email関連の処理
  module Email
    SEND_NKF_OPTIONS = {
      "shift_jis"   => "-sWx --no-cp932",
      "iso-2022-jp" => "-jW",
    }
    RECEIVE_NKF_OPTIONS = {
      "shift_jis"   => "-wSx --no-cp932",
      "iso-2022-jp" => "-wJ",
      "euc-jp"      => "-wE",
      "utf-8"       => "-wW",
    }
    NKF_CONSTANTS = {
      "shift_jis"   => NKF::SJIS,
      "iso-2022-jp" => NKF::JIS,
      "euc-jp"      => NKF::EUC,
      "utf-8"       => NKF::UTF8,
    }

    SUBJECT_REGEXP = %r!=\?(shift[_-]jis|iso-2022-jp|euc-jp|utf-8)\?B\?(.+)\?=!i

    RECEIVED_CONVERSION = {
      Jpmobile::Mobile::Docomo   => :external_to_unicodecr_docomo,
      Jpmobile::Mobile::Au       => :external_to_unicodecr_au_mail,
      Jpmobile::Mobile::Softbank => :external_to_unicodecr_softbank,
    }

    # +str+内の全角のチルダ(0xff5e)を波ダッシュ(0x301c)に変換する
    def self.tilda_to_dash(str)
      str.gsub([0xff5e].pack("U"), [0x301c].pack("U"))
    end

    # +recipients+に応じてパラメータを返す
    # ActionMailer::Base.receive で必要な前処理
    def self.prepare_create_mail(recipients, body, subject, parts, pc_convert = false)
      mobile = detect(recipients).new({}) rescue nil

      # subject 変換
      subject = tilda_to_dash(subject)
      subject = Jpmobile::Emoticon.utf8_to_unicodecr(subject)

      if recipients.kind_of?(String) and mobile
        pc_converting = false
      elsif pc_convert
        subject = NKF.nkf("-jW", subject)
        charset = "iso-2022-jp"

        pc_converting = true
      end

      # 本文変換 => multipart 判定
      if parts.empty?
        # plain mail
        body = tilda_to_dash(body)
        body = Jpmobile::Emoticon.utf8_to_unicodecr(body)

        if pc_converting
          body = NKF.nkf("-jW", body)
        end
      else
        # multipart mail
        parts.map do |part|
          pbody = tilda_to_dash(part.body)
          pbody = Jpmobile::Emoticon.utf8_to_unicodecr(pbody)

          if pc_converting
            pbody = NKF.nkf("-jW", pbody)
            part.body = pbody
            part.charset = "iso-2022-jp"
          else
            part.body = pbody
          end

          if part.content_type == "text/plain"
            case mobile
            when Jpmobile::Mobile::Docomo, Jpmobile::Mobile::Softbank
              part.charset = "shift_jis"
              part.transfer_encoding = "8bit"
            when Jpmobile::Mobile::Au, Jpmobile::Mobile::Vodafone
              part.charset = "iso-2022-jp"
              part.transfer_encoding = "7bit"
            end
          end

          part
        end
      end

      [mobile, subject, body, parts, charset]
    end

    # +mail+の中身を+mobile+に応じて変換する
    # mail :: TMail::Mailのインスタンス
    #         mail.subject, mail.body, mail.parts, mail.header が書き換えられる
    def self.convert_encoding(mail, mobile)
      mail_encode = mobile ? mobile.mail_encoding.first : "iso-2022-jp"
      nkf_opts = SEND_NKF_OPTIONS[mail_encode]

      # 題名変換
      jpm_subject = unicodecr_to_email_encoding(mail.subject, mobile, mail_encode)
      jpm_subject = "=?#{mail_encode}?B?" + [jpm_subject].pack("m").delete("\r\n") + "?="

      # キャリアによって変換手法を変える
      case mobile
      when Jpmobile::Mobile::Au, Jpmobile::Mobile::Vodafone, Jpmobile::Mobile::Jphone
        # iso-2022-jp はそのまま
        mail.subject = jpm_subject
      else
        # 漢字コード変換した場合は直接インスタンス変数に代入する
        mail.header["subject"].instance_variable_set(:@body, jpm_subject)
      end

      # 本文変換
      if mail.parts.empty?
        # plain mail
        mail.body = convert_mail_body(mail, mobile, mail_encode)
      else
        # multipart mail
        mail.parts.map do |part|
          case part.content_type
          when "text/plain"
            part.body = convert_mail_body(part, mobile, mail_encode)
          when "text/html"
            jpm_body = convert_mail_body(part, mobile, mail_encode)
            case mobile
            when Jpmobile::Mobile::Au, Jpmobile::Mobile::Vodafone, Jpmobile::Mobile::Jphone
              part.body = [jpm_body].pack("M*")
            when Jpmobile::Mobile::Docomo, Jpmobile::Mobile::Softbank
              part.charset = mail_encode
              part.transfer_encoding = "Base64"
              part.body = [jpm_body].pack("m")
            else
              part.body = [jpm_body].pack("M*")
            end
          end

          part
        end
      end
    end

    #+mobile+に応じて+mail+の中身を変換する
    # mail :: TMail::Mailのインスタンス
    def self.convert_mail_body(mail, mobile, mail_encode)
      case mail_encode
      when "iso-2022-jp"
        jpm_body = mail.quoted_body
      else
        jpm_body = mail.body
      end

      case mobile
      when Jpmobile::Mobile::Au,Jpmobile::Mobile::Vodafone, Jpmobile::Mobile::Jphone
        jpm_body = jpm_body.unpack("M*").first
      when Jpmobile::Mobile::Docomo, Jpmobile::Mobile::Softbank
      else
        jpm_body = jpm_body.unpack("M*").first
      end

      unicodecr_to_email_encoding(jpm_body, mobile, mail_encode)
    end

    # +mobile+に応じて+str+を変換する。主にbody変換
    def self.unicodecr_to_email_encoding(str, mobile, mail_encode)
      Jpmobile::Emoticon.unicodecr_to_email(NKF.nkf(SEND_NKF_OPTIONS[mail_encode], str), mobile)
    end

    # 受信した+mail+内の+subject+を変換する
    def self.prepare_receive_mail_subject(mail, mobile)
      header = mail.instance_variable_get(:@header)
      subject = header["subject"].instance_variable_get(:@body)
      if subject.match(SUBJECT_REGEXP)
        code    = $1
        subject = $2
      else
        code = case NKF.guess(subject)
               when NKF::JIS
                 "iso-2022-jp"
               when NKF::EUC
                 "euc-jp"
               when NKF::SJIS
                 "shift_jis"
               when NKF::UTF8
                 "utf-8"
               end
      end

      mail_emoticon_to_unicodecr(subject.unpack('m').first, mobile, code)
    end

    # 受信した+mail+内の本文を変換する
    def self.prepare_receive_mail_body(mail, mobile)
      if mail.multipart?
        # multipart
        mail.parts.map do |part|
          prepare_receive_mail_body(part, mobile)
        end

        mail
      else
        case mail.content_type
        when "text/plain"
          # text/plain
          if mobile.kind_of?(Jpmobile::Mobile::Au)
            body = mail.quoted_body.gsub(/\x1b\x24\x42(.*)\x1b\x28\x42/) do |jis|
              Jpmobile::Emoticon.external_to_unicodecr_au_mail(jis)
            end
            mail.body = NKF.nkf(Jpmobile::Email::RECEIVE_NKF_OPTIONS[mail.charset], body)
          else
            mail.body = mail_emoticon_to_unicodecr(mail.quoted_body, mobile, mail.charset)
          end
        when "text/html"
          # text/html
          body = transfer_decode(mail.quoted_body, mail.transfer_encoding)

          if mobile.kind_of?(Jpmobile::Mobile::Au)
            body = body.gsub(/\x1b\x24\x42(.*)\x1b\x28\x42/) do |jis|
              Jpmobile::Emoticon.external_to_unicodecr_au_mail(jis)
            end
            mail.body = NKF.nkf(Jpmobile::Email::RECEIVE_NKF_OPTIONS[mail.charset], body)
          else
            mail.body = mail_emoticon_to_unicodecr(body, mobile, mail.charset)
          end

          mail.transfer_encoding = nil
        end
        mail.charset = "utf-8"

        mail
      end
    end

    # +str+内の絵文字を+mobile+と+code+に応じて変換する
    def self.mail_emoticon_to_unicodecr(str, mobile, code)
      if mobile.kind_of?(Jpmobile::Mobile::Softbank) and code =~ /^shift_jis$/i
        # softbank で shift_jis の場合のみ変換テーブルが特例
        str = Jpmobile::Emoticon.send("#{RECEIVED_CONVERSION[mobile.class]}_sjis".to_sym, str)
      else
        str = Jpmobile::Emoticon.send(RECEIVED_CONVERSION[mobile.class], str)
      end
      NKF.nkf(Jpmobile::Email::RECEIVE_NKF_OPTIONS[code.downcase], str)
    end

    # +str+を+encoding+に応じてunpackする
    def self.transfer_decode(str, encoding)
      case encoding
      when /quoted-printable/i
        str.unpack("M*").first
      when /base64/i
        str.unpack("m").first
      else
        str
      end
    end

    # メールアドレスよりキャリア情報を取得する
    # _param1_:: email メールアドレス
    # return  :: Jpmobile::Mobileで定義されている携帯キャリアクラス
    def self.detect(email)
      Jpmobile::Mobile.carriers.each do |const|
        c = Jpmobile::Mobile.const_get(const)
        return c if c::MAIL_ADDRESS_REGEXP && email =~ c::MAIL_ADDRESS_REGEXP
      end
      nil
    end
  end
end
