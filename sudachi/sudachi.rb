#!/usr/bin/env ruby
require 'csv'
require 'nkf'
require 'yaml'
require 'optparse'

##### CONSTANTS #####
ROUND = !(ENV["WORDCLASS_ROUND"]&.downcase == "no")
ERROR_UNEXPECTED_CLS = ENV["ERROR_ON_UNEXPECTED_CLASS"]&.downcase == "yes"
#####################

CLASS_MAP = YAML.load(File.read("clsmap.yaml"))

ID_DEF = {}
ALREADY = {}

unless ENV["MOZC_ID_FILE"]
  abort "Mozc ID Definition File is not given."
end

# Load Mozc ID definition.
File.open(ENV["MOZC_ID_FILE"], "r") do |f|
  f.each do |line|
    id, expr = line.chomp.split(" ", 2)
    ID_DEF[expr] = id
  end
end

$opts = {}
op = OptionParser.new
op.on("-e", "--english")
op.parse!(ARGV, into: $opts)

# baseball heroes,4785,4785,5000,BASEBALL HEROES,名詞,固有名詞,一般,*,*,*,ベースボールヒーローズ,BASEBALL HEROES,*,A,*,*,*,*
# 見出し (TRIE 用),左連接ID,右連接ID,コスト,見出し (解析結果表示用), 品詞1,品詞2,品詞3,品詞4,品詞 (活用型),品詞 (活用形), 読み,正規化表記,辞書形ID,分割タイプ,A単位分割情報,B単位分割情報,※未使用

["src/core_lex.csv", "src/notcore_lex.csv"].each do |source_file|
  CSV.foreach(source_file) do |row|
    head_trie, lid, rid, cost, head_anal, cls1, cls2, cls3, cls4, cls5, cls6, kana, normal, did, dtype, adiv, bdiv = *row

    # 読みがかなで構成されていないものを除外する
    next if kana =~ /[^\p{hiragana}\p{katakana}ー]/

    yomi = NKF.nkf("--hiragana -w -W", kana).tr("ゐゑ", "いえ")

    # 見出し (解析結果表示用)を表記とみなす
    base = head_anal
    
    # head_trie と conv_to が casecmp false な例:
    # ["co・cp共済", "4785", "4785", "15000", "CO･CP共済", "名詞", "固有名詞", "一般", "*", "*", "*", "コープキョウサイ", "コープ共済", "*", "A", "*", "*", "*", "021722"]
    # Mozcdic-UTではスキップされていたが、こちらは単純に解析結果表示用を採用することとする
    # next unless head_trie.casecmp(conv_to).zero?

    # 名詞以外の場合はスキップ => しない
    # 「地名」をスキップ。地名は郵便番号ファイルから生成する => 踏襲
    next if cls3 == "地名"
		# 「名」をスキップ => しない

    clsexpr = [cls1, cls2, cls3, cls4, cls5, cls6].join(",")
    cost = cost.to_i

    # コスト計算の処理はMozc-UTに倣っている
    mozc_cost = case
    when cost < 0
      # コストがマイナスの場合は8000にする
      8000
    when cost > 10000
      # コストが10000を超える場合は10000にする
      10000
    else
      # コストを 6000 < cost < 7000 に調整する
      6000 + (cost / 10)
    end

    ##### List class (develop feature) #####
    # puts clsexpr
    # next

    # 既知のクラスの変換
    id = ID_DEF[CLASS_MAP[clsexpr]]

    # 品詞が特定できないケース
    if !id
      ERROR_UNEXPECTED_CLS ? abort("Unexpected Word Class #{clsexpr}") : next
    end

    # 英語への変換はオプションによる (デフォルトスキップ)
    # 固有名詞は受け入れる
    next if (!$opts[:english] && base =~ /^[a-zA-Z ]+$/ && !clsexpr.include?("固有名詞") )

    line_expr = [yomi, id, id, mozc_cost, base].join("\t")
    generic_expr = [yomi, id, base].join(" ")
    if ALREADY[generic_expr]
      next
    else
      ALREADY[generic_expr] = true
    end
  
    puts line_expr
  end
end