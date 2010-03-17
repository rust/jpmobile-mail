$KCODE='u'
module Jpmobile
  module Emoticon
    SJIS_TO_UNICODE = {}
    SJIS_TO_UNICODE.update(DOCOMO_SJIS_TO_UNICODE)
    SJIS_TO_UNICODE.update(AU_SJIS_TO_UNICODE)
    SJIS_TO_UNICODE.freeze
    UNICODE_TO_SJIS = SJIS_TO_UNICODE.invert.freeze

    SJIS_TO_EMAIL_JIS = {0x81ac => 0x222E}
    SJIS_TO_EMAIL_JIS.update(AU_SJIS_TO_EMAIL_JIS)
    SJIS_TO_EMAIL_JIS.freeze

    SJIS_REGEXP = Regexp.union(*SJIS_TO_UNICODE.keys.map{|s| Regexp.compile(Regexp.escape([s].pack('n'),"s"),nil,'s')})
    SOFTBANK_WEBCODE_REGEXP = Regexp.union(*([/(?!)/n]+SOFTBANK_WEBCODE_TO_UNICODE.keys.map{|x| "\x1b\x24#{x}\x0f"}))

    DOCOMO_SJIS_REGEXP      = Regexp.union(*DOCOMO_SJIS_TO_UNICODE.keys.map{|s| Regexp.compile(Regexp.escape([s].pack('n'),"s"),nil,'s')})
    AU_SJIS_REGEXP          = Regexp.union(*AU_SJIS_TO_UNICODE.keys.map{|s| Regexp.compile(Regexp.escape([s].pack('n'),"s"),nil,'s')})
    SOFTBANK_UNICODE_REGEXP = Regexp.union(*SOFTBANK_UNICODE_TO_WEBCODE.keys.map{|x| [x].pack('U')}).freeze

    EMOTICON_UNICODES = UNICODE_TO_SJIS.keys|SOFTBANK_UNICODE_TO_WEBCODE.keys.map{|k|k+0x1000}
    UTF8_REGEXP = Regexp.union(*EMOTICON_UNICODES.map{|x| [x].pack('U')}).freeze

    # for PC conversion "GETA"
    CONVERSION_TABLE_TO_PC = Hash[*(CONVERSION_TABLE_TO_SOFTBANK.keys|CONVERSION_TABLE_TO_DOCOMO.keys|CONVERSION_TABLE_TO_AU.keys).map{|k| [k, 0x3013]}.flatten]
    # CONVERSION_TABLE_TO_SOFTBANK.each{|k, v| CONVERSION_TABLE_TO_PC[k] = 0x3013}
    # CONVERSION_TABLE_TO_DOCOMO.each{|k, v| CONVERSION_TABLE_TO_PC[k] = 0x3013}
    # CONVERSION_TABLE_TO_AU.each{|k, v| CONVERSION_TABLE_TO_PC[k] = 0x3013}

    SOFTBANK_SJIS_REGEXP = Regexp.union(*SOFTBANK_SJIS_TO_UNICODE.keys.map{|s| Regexp.compile(Regexp.escape([s].pack('n'),"s"),nil,'s')}).freeze

    AU_EMAILJIS_REGEXP = Regexp.union(*AU_EMAILJIS_TO_UNICODE.keys.map{|s| Regexp.compile(Regexp.escape([s].pack('n'),"j"),nil,'j')})
    # AU_EMAILJIS_REGEXP = /(.+?)\c[\$B([\s\S]+?)\c[(\(B|\(J|\$@|\$B)([\s\S]+)/
    # AU_EMAILJIS_REGEXP = Regexp.union(*AU_EMAILJIS_TO_UNICODE.keys.map{|s| s.unpack("H*")})
    # AU_EMAILJIS_REGEXP = Regexp.union(*AU_EMAILJIS_TO_UNICODE.keys.map{|s| Regexp.compile("%X" % s, nil, 'j')})
  end
end
