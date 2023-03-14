#! /usr/bin/env ruby
# coding: UTF-8
require 'csv'
require 'nkf'
require 'optparse'
require 'parallel'

ID_DEF = {}
ALREADY = {}

$opts = { threads: 18, slice: 8000,
          filename: "src/seed/user-dict-seed.csv",
          fileencoding: 'UTF-8',
          need_convert: false,
          idfile: "../../mozc/src/data/dictionary_oss/id.def"
}

op = OptionParser.new
op.on("-e", "--english")
op.on('-tNUM', '--threads=NUM', Integer ) { |v| $opts[:threads] = v }
op.on('-sNUM', '--slice=NUM', Integer ) { |v| $opts[:slice] = v }
op.on('-fVAL', '--filename=VAL', String ) { |v| $opts[:filename] = v }
op.on('-iVAL', '--idfile=VAL', String ) { |v| $opts[:idfile] = v }
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
    ID_DEF[expr] = id
  end
end

# parallel
THREAD_NUM=$opts[:threads]
SLICE_NUM=$opts[:slice]

# Read CSV each line from file.
file = CSV.open($opts[:filename], "r", col_sep: "\t", encoding: $opts[:fileencoding], liberal_parsing: true)
file.each_slice(SLICE_NUM) do |rows|
  # 読み,左文脈ID,右文脈ID,コスト,原形
  results = Parallel.map(rows, in_threads: THREAD_NUM) do | row |
    if $opts[:need_convert]
      row.each do |x|
        next if x.nil?
        x.replace(NKF.nkf('-w', x))
      end
    end
    yomi, lcxid, rcxid, cost, base = row
    yomi = NKF.nkf("--hiragana -w -W", yomi).tr("ゐゑ", "いえ")

    # 読みがひらがな以外を含む場合はスキップ => 検証
    next if /[\p{hiragana}\p{katakana}]/ !~ yomi
    # 名詞以外の場合はスキップ => しない

    cost = cost.to_i

    ##### List class (develop feature) #####
    # puts clsexpr
    # next

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

    # idは探索を行う。
    # 未知のものは無視する
    id = lcxid
    next unless id

    # 英語への変換はオプションによる (デフォルトスキップ)
    # 固有名詞は受け入れる
    next if (!$opts[:english] && base =~ /^[a-zA-Z ]+$/ && !id.include?("固有名詞") )

    generic_expr = [yomi, id,  base].join(" ")
    if ALREADY[generic_expr]
      next
    else
      ALREADY[generic_expr] = true
      line_expr = [yomi, lcxid, rcxid , mozc_cost, base]
    end
  end
  results.map{ |x|
    next if x.nil?
    puts x.join("\t")
  }
end
