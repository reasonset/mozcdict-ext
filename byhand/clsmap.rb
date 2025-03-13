#!/usr/bin/ruby
require 'yaml'
require_relative '../lib/dictutils'

ID_MAP = YAML.load(File.read "def.yaml")

BYHAND_CLSMAP = {
  "一段動詞" => ->(wp) {
    wp.w "動詞,自立,*,*,一段,未然形,*"
    wp.w "動詞,自立,*,*,一段,連用形,*"
    wp.w "動詞,自立,*,*,一段,命令ｙｏ,*", add: "よ"
    wp.w "動詞,自立,*,*,一段,未然ウ接続,*", add: "よ"
    wp.w "動詞,自立,*,*,一段,体言接続特殊,*", add: "ん"
  },
  "一段動詞る" => ->(wp) {
    wp.w "動詞,自立,*,*,一段,仮定縮約１,*", add: "りゃ"
    wp.w "動詞,自立,*,*,一段,命令ｒｏ,*", add: "ろ"
    wp.w "動詞,自立,*,*,一段,基本形,*", add: "る"
    wp.dg "一段動詞"
  }
}

class WordProcessor
  def initialize(yomi, base, cls)
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

  def wordout(c, remove: "", add: "")
    conjugation = c.split(",")[5]
    return if @excludes.include? conjugation
    puts [@yomi.delete_suffix(remove) + add, ID_DEF[c], ID_DEF[c], COST, @base.delete_suffix(remove) + add].join("\t")
  end

  def dg(cls)
    return if check_containing_fullwidth_english @base, cls
    BYHAND_CLSMAP[cls].call(self)
  end  

  alias :w :wordout
end

def process_cls(yomi, base, cls)
  word_classes = nil
  scls = cls.sub(%r:/.*:, "")
  if BYHAND_CLSMAP[scls]
    wp = WordProcessor.new(yomi, base, cls)
    wp.dg scls
  elsif ID_MAP[cls]
    # 単純変換
    ID_MAP[cls].each do |cls|
      # Mozcの品詞IDを取得する
      id = ID_DEF[cls]
 
      
      next if check_containing_fullwidth_english base, cls
      # 出力
      puts [yomi, id, id, COST, base].join("\t")
    end
  else
    # 未知の品詞 (未作業、もしくは直接指定)
    if check_containing_fullwidth_english(base, cls)
      id = ID_DEF[cls]
      puts [yomi, id, id, COST, base].join("\t")
    end
  end
end