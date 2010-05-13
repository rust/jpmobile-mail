# -*- coding: utf-8 -*-
# =SoftBank携帯電話
# J-PHONE, Vodafoneを含む
module Jpmobile::Mobile
  # Vodafone, Jphoneのスーパクラス。
  class Softbank < AbstractMobile
    # メールエンコーディング情報
    def mail_encoding
      ["shift_jis", true] # shift_jis 変換
    end
  end

  # ==Vodafone 3G携帯電話(J-PHONE, SoftBank含まず)
  # スーパクラスはSoftbank。
  class Vodafone < Softbank
    # メールエンコーディング情報
    def mail_encoding
      ["iso-2022-jp", false] # jis 変換
    end
  end

  # スーパクラスはVodafone。
  class Jphone < Vodafone
    # メールエンコーディング情報
    def mail_encoding
      ["iso-2022-jp", false] # jis 変換
    end
  end
end
