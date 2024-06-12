#!/usr/bin/ruby
require 'yaml'

ID_MAP = YAML.load(File.read "def.yaml")


BYHAND_CLSMAP = {
  "一段動詞える" => ->(wp) {
    wp.w "動詞,非自立,*,*,一段,仮定形,える", "る"
    wp.w "動詞,非自立,*,*,一段,仮定縮約１,える", "る"
    wp.w "動詞,非自立,*,*,一段,体言接続特殊,える", "る"
    wp.w "動詞,非自立,*,*,一段,命令ｒｏ,える", "る"
    wp.w "動詞,非自立,*,*,一段,命令ｙｏ,える", "る"
    wp.w "動詞,非自立,*,*,一段,基本形,える"
    wp.w "動詞,非自立,*,*,一段,未然ウ接続,える", "る"
    wp.w "動詞,非自立,*,*,一段,未然形,える", "る"
    wp.w "動詞,非自立,*,*,一段,連用形,える", "る"
  },
  "サ変一段動詞える" => ->(wp) {
    wp.w "名詞,サ変接続,*,*,*,*,*", "る"
    wp.dg "一段動詞える"
  },
}

class WordProcessor
  def initialize(base, yomi, cls)
    @base = base
    @yomi = yomi
    if cls.include?("/")
      @spec_cls = cls.sub(%r:/.*:, "")
      @excludes = cls.sub(%r:.*/:, "").split(",")
    else
      @spec_cls = cls
      @excludes = []
    end
  end

  def wordout(c, remove = "", add = "")
    conjugation = c.split(",")[5]
    return if @excludes.include? conjugation
    puts [@yomi.delete_suffix(remove) + add, ID_DEF[c], ID_DEF[c], COST, @base.delete_suffix(remove) + add].join("\t")
  end

  def dg(cls)
    BYHAND_CLSMAP[cls].call(self)
  end  

  alias :w :wordout
end

def process_cls(base, yomi, cls)
  word_classes = nil
  scls = cls.sub(%r:/.*:, "")
  if BYHAND_CLSMAP[scls]
    wp = WordProcessor.new(base, yomi, cls)
    wp.dg scls
  elsif ID_MAP[cls]
    # 単純変換
    ID_MAP[cls].each do |cls|
      # Mozcの品詞IDを取得する
      id = ID_DEF[cls]
  
      # 出力
      puts [yomi, id, id, COST, base].join("\t")
    end
  else
    # 未知の品詞 (未作業、もしくは直接指定)
    id = ID_DEF[cls]
    puts [yomi, id, id, COST, base].join("\t")
  end
end