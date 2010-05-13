# -*- coding: utf-8 -*-
module Jpmobile::Mobile
  class AbstractMobile
    # メールエンコーディング情報
    def mail_encoding
      ["iso-2022-jp", true] # iso-2022-jp 変換
    end
  end
end
