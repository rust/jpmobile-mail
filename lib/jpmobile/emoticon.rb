# -*- coding: utf-8 -*-
require 'nkf'

module Jpmobile
  # 絵文字関連処理
  module Emoticon
    %w( DOCOMO_SJIS_TO_UNICODE DOCOMO_UNICODE_TO_SJIS ).each do |const|
      autoload const, 'jpmobile/emoticon/docomo'
    end
    autoload :AU_SJIS_TO_UNICODE,           'jpmobile/emoticon/au'
    %w( SOFTBANK_UNICODE_TO_WEBCODE SOFTBANK_WEBCODE_TO_UNICODE ).each do |const|
      autoload const, 'jpmobile/emoticon/softbank'
    end
    %w( CONVERSION_TABLE_TO_DOCOMO CONVERSION_TABLE_TO_AU CONVERSION_TABLE_TO_SOFTBANK ).each do |const|
      autoload const, 'jpmobile/emoticon/conversion_table'
    end
    %w(
      SJIS_TO_UNICODE UNICODE_TO_SJIS
      SJIS_REGEXP SOFTBANK_WEBCODE_REGEXP DOCOMO_SJIS_REGEXP AU_SJIS_REGEXP SOFTBANK_UNICODE_REGEXP
      EMOTICON_UNICODES UTF8_REGEXP
    ).each do |const|
      autoload const, 'jpmobile/emoticon/z_combine'
    end

    # +str+ のなかでDoCoMo絵文字をUnicode数値文字参照に置換した文字列を返す。
    def self.external_to_unicodecr_docomo(str)
      str.gsub(DOCOMO_SJIS_REGEXP) do |match|
        sjis = match.unpack('n').first
        unicode = DOCOMO_SJIS_TO_UNICODE[sjis]
        unicode ? ("&#x%04x;"%unicode) : match
      end
    end

    # +str+ のなかでau絵文字をUnicode数値文字参照に置換した文字列を返す。
    def self.external_to_unicodecr_au(str)
      str.gsub(AU_SJIS_REGEXP) do |match|
        sjis = match.unpack('n').first
        unicode = AU_SJIS_TO_UNICODE[sjis]
        unicode ? ("&#x%04x;"%unicode) : match
      end
    end
    # +str+ のなかでau絵文字をUnicode数値文字参照に置換した文字列を返す。(メール専用)
    def self.external_to_unicodecr_au_mail(str)
      str.gsub(AU_EMAILJIS_REGEXP) do |match|
        jis = match.unpack('n').first
        unicode = AU_EMAILJIS_TO_UNICODE[jis]
        unicode ? ("\x1b\x28\x42&#x%04x;\x1b\x24\x42"%unicode) : match
      end
    end

    # +str+のなかでUTF8のSoftBank絵文字を(+0x1000だけシフトして)Unicode数値文字参照に変換した文字列を返す。
    def self.external_to_unicodecr_softbank(str)
      # SoftBank Unicode
      str.gsub(SOFTBANK_UNICODE_REGEXP) do |match|
        unicode = match.unpack('U').first
        "&#x%04x;" % (unicode+0x1000)
      end
    end
    def self.external_to_unicodecr_softbank_sjis(str)
      # SoftBank Shift_JIS
      str.gsub(SOFTBANK_SJIS_REGEXP) do |match|
        sjis = match.unpack('n').first
        unicode = SOFTBANK_SJIS_TO_UNICODE[sjis]
        "&#x%04x;" % (unicode+0x1000)
      end
    end
    def self.external_to_unicodecr_vodafone(str)
      external_to_unicodecr_softbank(str)
    end
    # +str+のなかでWebcodeのSoftBank絵文字を(+0x1000だけシフトして)Unicode数値文字参照に変換した文字列を返す。
    def self.external_to_unicodecr_jphone(str)
      # SoftBank Webcode
      s = str.clone
      # 連続したエスケープコードが省略されている場合は切りはなす。
      s.gsub!(/\x1b\x24(.)(.+?)\x0f/) do |match|
        a = $1
        $2.split(//).map{|x| "\x1b\x24#{a}#{x}\x0f"}.join('')
      end
      # Webcodeを変換
      s.gsub(SOFTBANK_WEBCODE_REGEXP) do |match|
        unicode = SOFTBANK_WEBCODE_TO_UNICODE[match[2,2]] + 0x1000
        unicode ? ("&#x%04x;"%unicode) : match
      end
    end

    # +str+ のなかでUnicode数値文字参照で表記された絵文字を携帯側エンコーディングに置換する。
    #
    # キャリア間の変換に +conversion_table+ を使う。+conversion_table+ に+nil+を与えると、
    # キャリア間の変換は行わない。
    #
    # 携帯側エンコーディングがShift_JIS場合は +to_sjis+ に +true+ を指定する。
    # +true+ を指定すると変換テーブルに文字列が指定されている場合にShift_JISで出力される。
    def self.unicodecr_to_external(str, conversion_table=nil, to_sjis=true)
      str.gsub(/&#x([0-9a-f]{4});/i) do |match|
        unicode = $1.scanf("%x").first
        if conversion_table
          converted = conversion_table[unicode] # キャリア間変換
        else
          converted = unicode # 変換しない
        end

        # 携帯側エンコーディングに変換する
        case converted
        when Integer
          # 変換先がUnicodeで指定されている。つまり対応する絵文字がある。
          if sjis = UNICODE_TO_SJIS[converted]
            [sjis].pack('n')
          elsif webcode = SOFTBANK_UNICODE_TO_WEBCODE[converted-0x1000]
            "\x1b\x24#{webcode}\x0f"
          elsif converted == 0x3013
            # ゲタ「〓」の場合はそれに変換する
            converted = [converted].pack("U")

            if to_sjis
              Kconv::kconv(converted, Kconv::SJIS, Kconv::UTF8)
            else
              Kconv::kconv(converted, Kconv::JIS, Kconv::UTF8)
            end
          else
            # キャリア変換テーブルに指定されていたUnicodeに対応する
            # 携帯側エンコーディングが見つからない(変換テーブルの不備の可能性あり)。
            match
          end
        when String
          # 変換先が数値参照だと、再変換する
          if converted.match(/&#x([0-9a-f]{4});/i)
            self.unicodecr_to_external(converted, conversion_table, to_sjis)
          else
            # FIXME: 絵文字の代替が文章でいいかどうかの検証
            # 変換先が文字列で指定されている。
            to_sjis ? NKF.nkf('-m0 -x -Ws', converted) : converted
          end
        when nil
          # 変換先が定義されていない。
          match
        end
      end
    end

    # +str+ のなかでUnicode数値文字参照で表記された絵文字をUTF-8に置換する。
    def self.unicodecr_to_utf8(str)
      str.gsub(/&#x([0-9a-f]{4});/i) do |match|
        unicode = $1.scanf("%x").first
        if UNICODE_TO_SJIS[unicode] || SOFTBANK_UNICODE_TO_WEBCODE[unicode-0x1000]
          [unicode].pack('U')
        else
          match
        end
      end
    end
    # +str+ のなかでUTF-8で表記された絵文字をUnicode数値文字参照に置換する。
    def self.utf8_to_unicodecr(str)
      str.gsub(UTF8_REGEXP) do |match|
        "&#x%04x;" % match.unpack('U').first
      end
    end

    # +str+ のなかでUnicode数値文字参照で表記された絵文字を
    # +carrier+ 用のメール送信用コードに変換する
    def self.unicodecr_to_email(str, carrier = nil, to_sjis = true)
      case carrier
      when Jpmobile::Mobile::Docomo
        unicodecr_to_external(str, CONVERSION_TABLE_TO_DOCOMO, to_sjis)
      when Jpmobile::Mobile::Au
        unicodecr_to_au_email(str)
      when Jpmobile::Mobile::Vodafone, Jpmobile::Mobile::Jphone
        unicodecr_to_external(str, CONVERSION_TABLE_TO_PC, false)
      when Jpmobile::Mobile::Softbank
        unicodecr_to_softbank_email(str)
      else
        unicodecr_to_external(str, CONVERSION_TABLE_TO_PC, false)
      end
    end

    private
    def self.unicodecr_to_au_email(str)
      str.gsub(/&#x([0-9a-f]{4});/i) do |match|
        unicode = $1.scanf("%x").first
        converted = CONVERSION_TABLE_TO_AU[unicode]

        # メール用エンコーディングに変換する
        case converted
        when Integer
          if sjis = UNICODE_TO_SJIS[converted]
            if email_jis = SJIS_TO_EMAIL_JIS[sjis]
              "\x1b\x24\x42#{[email_jis].pack('n')}\x1b\x28\x42"
            else
              [sjis].pack('n')
            end
          else
            match
          end
        when String
          # FIXME: 絵文字の代替が文章でいいかどうかの検証
          Kconv::kconv(converted, Kconv::JIS, Kconv::UTF8)
        else
          match
        end
      end
    end

    # +str+ のなかでUnicode数値文字参照で表記された絵文字をメール送信用JISコードに変換する
    # softbank 専用
    def self.unicodecr_to_softbank_email(str)
      str.gsub(/&#x([0-9a-f]{4});/i) do |match|
        unicode = $1.scanf("%x").first
        converted = CONVERSION_TABLE_TO_SOFTBANK[unicode]

        # メール用エンコーディングに変換する
        case converted
        when Integer
          if sjis = SOFTBANK_UNICODE_TO_SJIS[converted-0x1000]
            [sjis].pack('n')
          else
            match
          end
        when String
          # FIXME: 絵文字の代替が文章でいいかどうかの検証
          Kconv::kconv(converted, Kconv::SJIS, Kconv::UTF8)
        else
          match
        end
      end
    end
  end
end
