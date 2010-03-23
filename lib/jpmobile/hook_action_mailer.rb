# -*- coding: utf-8 -*-
# 絵文字と文字コードの変換処理
#   とりあえず1ファイルに書く

module TMail
  # convert_to で機種依存文字や絵文字に対応するために
  # Unquoter 内で NKF を使用するようにしたもの
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

  # ピリオドが3つ以上連続する場合やピリオドから始まるアドレス対策
  # RFC 違反であるが利用されているので対策する
  class Mail
    alias_method :processed_destinations, :destinations

    def destinations(default = nil)
      ret = processed_destinations(default)
      if ret.nil? || ret.empty?
        ary = []
        %w(to cc bcc).each do |var_name|
          if @unmodified_header[var_name.to_sym]
            ary += [@unmodified_header[var_name.to_sym]].flatten
          end
        end
        ary
      else
        ret
      end
    end

    %w(to cc bcc).each do |var_name|
      class_eval <<-END_CLASS_EVAL
        alias_method :"processed_#{var_name}=", :"#{var_name}="
        def #{var_name}=(*strs)
          self.processed_#{var_name} = *strs
          @unmodified_header ||= {}
          @unmodified_header[:#{var_name}] = *strs
        end

        alias_method :processed_#{var_name}, :#{var_name}
        def #{var_name}(default = nil)
          ret = processed_#{var_name}
          if ret
            ret
          elsif @unmodified_header
            @unmodified_header[:#{var_name}]
          else
            nil
          end
        end
      END_CLASS_EVAL
    end
  end
end

module ActionMailer
  class Base
    alias :create_without_jpmobile! :create!
    alias :create_mail_without_jpmobile :create_mail

    cattr_accessor :pc_convert

    def create_mail
      @mobile, @subject, @body, @parts, @charset =
        Jpmobile::Email.prepare_create_mail(recipients, @body, @subject, @parts, @@pc_convert)

      create_mail_without_jpmobile
    end

    def create!(method_name, *parameters)
      create_without_jpmobile!(method_name, *parameters)

      return @mail unless @mobile or @@pc_convert

      # TMail::Mail の encoded を hook する
      @mail.instance_eval do
        def emoji_convert(mobile = nil)
          @mobile = mobile
        end

        alias :encoded_without_jpmobile :encoded

        def encoded
          Jpmobile::Email.convert_encoding(self, @mobile)

          encoded_without_jpmobile
        end
      end

      # 絵文字・漢字コード変換
      @mail.emoji_convert(@mobile)

      @mail
    end

    # receive
    class << self
      # # original in ActionMailer::Base 2.3.5
      # def receive(raw_email)
      #   logger.info "Received mail:\n #{raw_email}" unless logger.nil?
      #   mail = TMail::Mail.parse(raw_email)
      #   mail.base64_decode
      #   new.receive(mail)
      # end

      def receive(raw_email)
        logger.info "Received mail:\n #{raw_email}" unless logger.nil?
        mail    = TMail::Mail.parse(raw_email)

        @mobile = Jpmobile::Email.detect(mail.from.first).new({}) rescue nil

        if @mobile
          # 題名変換
          mail.subject = Jpmobile::Email.prepare_receive_mail_subject(mail, @mobile)

          mail.body = Jpmobile::Email.prepare_receive_mail_body(mail, @mobile)
          mail.charset = "utf-8"
        end

        mail.base64_decode
        new.receive(mail)
      end

      private
      def extract_body(email)
        if email.multipart?
          email.parts.each do |part|
            if part.content_type == "text/plain"
              return [part.quoted_body, part.charset]
            end
          end
        else
          [email.quoted_body, email.charset]
        end
      end
    end
  end
end
