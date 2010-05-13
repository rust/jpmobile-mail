$KCODE='u'
module Jpmobile
  module Emoticon
    SJIS_TO_EMAIL_JIS = {0x81ac => 0x222E}
    SJIS_TO_EMAIL_JIS.update(AU_SJIS_TO_EMAIL_JIS)
    SJIS_TO_EMAIL_JIS.freeze

    # for PC conversion "GETA"
    CONVERSION_TABLE_TO_PC = Hash[*(CONVERSION_TABLE_TO_SOFTBANK.keys|CONVERSION_TABLE_TO_DOCOMO.keys|CONVERSION_TABLE_TO_AU.keys).map{|k| [k, 0x3013]}.flatten]

    SOFTBANK_SJIS_REGEXP = Regexp.union(*SOFTBANK_SJIS_TO_UNICODE.keys.map{|s| Regexp.compile(Regexp.escape([s].pack('n'),"s"),nil,'s')}).freeze
    AU_EMAILJIS_REGEXP = Regexp.union(*AU_EMAILJIS_TO_UNICODE.keys.map{|s| Regexp.compile(Regexp.escape([s].pack('n'),"j"),nil,'j')})
  end
end
