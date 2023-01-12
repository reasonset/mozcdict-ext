#! /usr/bin/env ruby
require 'csv'
require 'nkf'

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

# Read CSV each line from file.
CSV.foreach("src/seed/user-dict-seed.csv") do |row|
  # 表層形,左文脈ID,右文脈ID,コスト,品詞1,品詞2,品詞3,品詞4,品詞5,品詞6,原形,読み,発音
  # #24時間以内に240RT来なければ俺の嫁,1288,1288,3942,名詞,固有名詞,一般,*,*,*,#24時間以内に240RT来なければ俺の嫁,ニジュウヨジカンイナイニニヒャクヨンジュウアールティーコナケレバオレノヨメ,ニジュウヨジカンイナイニニヒャクヨンジュウアールティーコナケレバオレノヨメ
  surface, lcxid, rcxid, cost, cls1, cls2, cls3, cls4, cls5, cls6, base, kana, pron = *row

  yomi = NKF.nkf("--hiragana -w -W", kana).tr("ゐゑ", "いえ")

  # 読みがひらがな以外を含む場合はスキップ => 検証
  # 名詞以外の場合はスキップ => しない
  
  # 「地域」をスキップ。地名は郵便番号ファイルから生成する => 踏襲する
  next if cls3 == "地域"

  # 「名」をスキップ => しない

  clsexpr = [cls1, cls2, cls3, cls4, cls5, cls6].join(",")
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
  # 既知のNeologdのクラスを変換
  # 未知のものは無視する
  id = case clsexpr
  when "記号,一般,*,*,*,*"
    ID_DEF["記号,一般,*,*,*,*,*"]
  when "名詞,固有名詞,人名,一般,*,*"
    ID_DEF["名詞,固有名詞,人名,一般,*,*,*"]
  when "名詞,固有名詞,一般,*,*,*", "名詞,固有名詞,一般,*,*,"
    ID_DEF["名詞,固有名詞,一般,*,*,*,*"]
  when "名詞,固有名詞,組織,*,*,*"
    ID_DEF["名詞,固有名詞,組織,*,*,*,*"]
  when "名詞,一般,*,*,*,*"
    ID_DEF["名詞,一般,*,*,*,*,*"]
  when "名詞,サ変接続,*,*,*,*"
    ID_DEF["名詞,サ変接続,*,*,*,*,*"]
  when "名詞,固有名詞,人名,名,*,*"
    ID_DEF["名詞,固有名詞,人名,名,*,*,*"]
  when "名詞,固有名詞,人名,姓,*,*"
    ID_DEF["名詞,固有名詞,人名,姓,*,*,*"]
  end

  #raise unless id      # DEVELOPMENT MODE
  next unless id
  
  line_expr = [yomi, id, id, mozc_cost, base].join(" ")
  generic_expr = [yomi, id,  base].join(" ")
  if ALREADY[generic_expr]
    next
  else
    ALREADY[generic_expr] = true
  end

  puts line_expr
end
