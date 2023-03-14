#!/usr/bin/env ruby
# coding: UTF-8
require 'csv'
require 'nkf'
require 'yaml'
require 'optparse'
require 'parallel'

##### CONSTANTS #####
ROUND = !(ENV["WORDCLASS_ROUND"]&.downcase == "no")
ERROR_UNEXPECTED_CLS = ENV["ERROR_ON_UNEXPECTED_CLASS"]&.downcase == "yes"
#####################

CLASS_MAP = YAML.load(File.read("clsmap.yaml"))

ID_DEF = {}
ALREADY = {}

$opts = { threads: 18, slice: 8000,
          filename: [ "src/core_lex.csv", "src/notcore_lex.csv" ],
          idfile: "../../mozc/src/data/dictionary_oss/id.def"
}
op = OptionParser.new
op.on("-e", "--english")
op.on("-s", "--symbol")
op.on('-tNUM', '--threads=NUM', Integer ) { |v| $opts[:threads] = v }
op.on('-sNUM', '--slice=NUM', Integer ) { |v| $opts[:slice] = v }
op.on('-fVAL', '--filename=VAL', String ) { |v| $opts[:filename] = v }
op.on('-iVAL', '--idfile=VAL', String ){ |v| $opts[:idfile] = v }
op.on('-eVAL', '--encoding=VAL', String ) { |v| 
  $opts[:fileencoding] = v
  $opts[:need_convert] = true
}
op.parse!(ARGV, into: $opts)

unless ENV["MOZC_ID_FILE"]
  MOZC_ID_FILE=$opts[:idfile]
else
  MOZC_ID_FILE=ENV["MOZC_ID_FILE"]
end

# Load Mozc ID definition.
File.open(MOZC_ID_FILE, "r") do |f|
  f.each do |line|
    id, expr = line.chomp.split(" ", 2)
    #id.defの品詞の末尾要素を取り除く
    expr = expr.split(",")
    expr.pop
    expr = expr.join(",")
    ID_DEF[expr] = id
  end
end

# 一番近いだろう品詞を求める。
# 単純な判定なので、誤る場合もあります。
def id_expr(clsexpr)
  expr=clsexpr.split(",")
  r=nil
  q=0
  ID_DEF.keys.each do |h|
    p=0
    expr.each do |x|
      next if x == "*"
      i = h.split(",")
      i.each do |y|
        case y
        when "*","自立","非自立"
          next
        end
        if x == y
          p = p + 1
        end
      end
    end
    if q < p
      q = p
      r = ID_DEF[h]
    end
  end
  ID_DEF[clsexpr] = r if not ID_DEF.include?(clsexpr)
  CLASS_MAP[clsexpr] = clsexpr
  return r
end

# parallel
THREAD_NUM=$opts[:threads]
SLICE_NUM=$opts[:slice]

# baseball heroes,4785,4785,5000,BASEBALL HEROES,名詞,固有名詞,一般,*,*,*,ベースボールヒーローズ,BASEBALL HEROES,*,A,*,*,*,*
# 見出し (TRIE 用),左連接ID,右連接ID,コスト,見出し (解析結果表示用), 品詞1,品詞2,品詞3,品詞4,品詞 (活用型),品詞 (活用形), 読み,正規化表記,辞書形ID,分割タイプ,A単位分割情報,B単位分割情報,※未使用

#["src/core_lex.csv", "src/notcore_lex.csv"].each do |source_file|
[$opts[:filename]].each do |source_file|
  file = CSV.open(source_file, "r", encoding: $opts[:fileencoding], liberal_parsing: false)
  file.each_slice(SLICE_NUM) do |rows|
    results = Parallel.map(rows, in_threads: THREAD_NUM) do | row |
      if $opts[:need_convert]
        row.each do |x|
          next if x.nil?
          x.replace(NKF.nkf('-w', x))
        end
      end
      surface, lcxid, rcxid, cost, cls1, cls2, cls3, cls4, cls5, cls6, base, kana, pron = row
      head_trie, lid, rid, cost, head_anal, cls1, cls2, cls3, cls4, cls5, cls6, kana, normal, did, dtype, adiv, bdiv = *row

      # 読みがかなで構成されていないものを除外する
      #if /[^\u3040-\u309F]/ !~ yomi
      next if /[\p{hiragana}\p{katakana}]/ !~ kana
      #next if kana =~ /[^\p{hiragana}\p{katakana}ー]/

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
      if id.nil?
        id = id_expr(clsexpr)
        # 品詞が特定できないケース
        if id.nil?
          #STDERR.puts [row, clsexpr].join("\t")
          ERROR_UNEXPECTED_CLS ? abort("Unexpected Word Class #{clsexpr}") : next
        end
      end

      # 英語への変換はオプションによる (デフォルトスキップ)
      # 固有名詞は受け入れる
      next if (!$opts[:english] && base =~ /^[a-zA-Z ]+$/ && !clsexpr.include?("固有名詞") )

      # 「きごう」で変換される記号は多すぎて支障をきたすため、除外する
      next if (!$opts[:symbol] && yomi == "きごう" && clsexpr.include?("記号"))

      generic_expr = [yomi, id, base].join(" ")
      if ALREADY[generic_expr]
        next
      else
        ALREADY[generic_expr] = true
        line_expr = [yomi, id, id, mozc_cost, base]
      end
    end

    results.map{ |x|
      next if x.nil?
      puts x.join("\t")
    }
  end
end
