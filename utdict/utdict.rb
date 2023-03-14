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
    if $opts[:need_convert]
      line.replace(NKF.nkf('-Lu -w', line))
    end
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
def id_expr(expr)
  expr=expr.split(",")
  r=nil
  q=0
  ID_DEF.each do |h|
    p=0
    expr.each do |x|
      next if x == "*"
      i = h[0].split(",")
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
      r = h[1]
    end
  end
  return r
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
        x.replace(NKF.nkf('-Lu -w', x))
      end
    end
    yomi, lcxid, rcxid, cost, base = row
    yomi = NKF.nkf("--hiragana -w -W", yomi).tr("ゐゑ", "いえ")

    # 読みがひらがな以外を含む場合はスキップ => 検証
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
    id = ID_DEF.key(lcxid)
    if id.nil?
      STDERR.puts "id is nil. ", clsexpr
      id = id_expr(clsexpr) if id.nil?
    end
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
