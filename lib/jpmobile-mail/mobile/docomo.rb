# -*- coding: utf-8 -*-
module Jpmobile::Mobile
  class Docomo < AbstractMobile
    # メールエンコーディング情報
    def mail_encoding
      ["shift_jis", true] # shift_jis 変換
    end
  end
end
