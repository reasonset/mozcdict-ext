#!/usr/bin/ruby
require 'yaml'
require 'json'
require_relative '../lib/dictutils'

ID_MAP = YAML.load(File.read "def.yaml")
COST = 6500 # Default cost
COSTS = {
  "BINDED" => 5000,
  "HIGH" => 5500,
  "LOW" => 8000,
  "VERYLOW" => 9500
}

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
  },
  "自立五段動詞" => ->(wp) {
    INFLECTIONAL_MAPPER.godan wp
  }
}

class WordProcessor
  def initialize(yomi, base, cls, cost)
    @base = base
    @yomi = yomi
    @cost = cost
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
    puts [@yomi.delete_suffix(remove) + add, ID_DEF[c], ID_DEF[c], @cost, @base.delete_suffix(remove) + add].join("\t")
  end

  def dg(cls)
    return if check_containing_fullwidth_english @base, cls
    BYHAND_CLSMAP[cls].call(self)
  end

  def parse_variant variant
    return nil unless variant
    JSON.parse("{" + variant + "}")
  end

  alias :w :wordout
  attr_reader :yomi, :variant
end

def process_cls(yomi, base, cls, priority = "DEFAULT")
  current_cost = COSTS[priority] || COST

  word_classes = nil
  scls, variant = cls.split("/", 2)
  @variant = variant

  if BYHAND_CLSMAP[scls]
    wp = WordProcessor.new(yomi, base, cls, current_cost)
    wp.dg scls
  elsif ID_MAP[cls]
    # 単純変換
    ID_MAP[cls].each do |cls|
      # Mozcの品詞IDを取得する
      id = ID_DEF[cls]
      
      next if check_containing_fullwidth_english base, cls
      # 出力
      puts [yomi, id, id, current_cost, base].join("\t")
    end
  else
    # 未知の品詞 (未作業、もしくは直接指定)
    if check_containing_fullwidth_english(base, cls)
      id = ID_DEF[cls]
      puts [yomi, id, id, current_cost, base].join("\t")
    end
  end
end

module INFLECTIONAL_MAPPER
  # 基本形（u段）の文字をキーにして、各列の文字を引く
  GODAN_MAPPER = {
    "う" => {a: "わ", i: "い", u: "う", e: "え", o: "お"}, # ワ行
    "く" => {a: "か", i: "き", u: "く", e: "け", o: "こ"}, # カ行
    "ぐ" => {a: "が", i: "ぎ", u: "ぐ", e: "げ", o: "ご"}, # ガ行
    "す" => {a: "さ", i: "し", u: "す", e: "せ", o: "そ"}, # サ行
    "つ" => {a: "た", i: "ち", u: "つ", e: "て", o: "と"}, # タ行
    "ぬ" => {a: "な", i: "に", u: "ぬ", e: "ね", o: "の"}, # ナ行
    "ぶ" => {a: "ば", i: "び", u: "ぶ", e: "べ", o: "ぼ"}, # バ行
    "む" => {a: "ま", i: "み", u: "む", e: "め", o: "も"}, # マ行
    "る" => {a: "ら", i: "り", u: "る", e: "れ", o: "ろ"}  # ラ行
  }

  def self.godan wp
    row = GODAN_MAPPER[wp.yomi[-1]]
    raise "Undefined 五段活用 for #{wp.yomi[-1]}" unless row

    # 833 仮定形 (e)
    wp.w "動詞,自立,*,*,五段動詞,仮定形,*", remove: wp.yomi[-1], add: row[:e]
    # 834 仮定縮約１ (e)
    wp.w "動詞,自立,*,*,五段動詞,仮定縮約１,*", remove: wp.yomi[-1], add: row[:e]
    # 835 体言接続特殊 (u) 通常は基本形と同じ
    wp.w "動詞,自立,*,*,五段動詞,体言接続特殊,*", remove: wp.yomi[-1], add: row[:u]
    # 836 命令ｅ (e)
    wp.w "動詞,自立,*,*,五段動詞,命令ｅ,*", remove: wp.yomi[-1], add: row[:e]
    # 837 基本形 (u)
    wp.w "動詞,自立,*,*,五段動詞,基本形,*"
    # 838 未然ウ接続 (o)
    wp.w "動詞,自立,*,*,五段動詞,未然ウ接続,*", remove: wp.yomi[-1], add: row[:o]
    # 839 未然形 (a)
    wp.w "動詞,自立,*,*,五段動詞,未然形,*", remove: wp.yomi[-1], add: row[:a]
    # 840 未然特殊 (a)
    wp.w "動詞,自立,*,*,五段動詞,未然特殊,*", remove: wp.yomi[-1], add: row[:a] unless wp.variant&.[]("未然特殊")
    # 842 連用形 (i)
    wp.w "動詞,自立,*,*,五段動詞,連用形,*", remove: wp.yomi[-1], add: row[:i]

    # 841 連用タ接続 は別途個別処理（音便があるため）
  end
end
