#! /usr/bin/env ruby
require 'nkf'


# ==============================================================================
# convert_neologd_to_mozcdic
# ==============================================================================

def convert_neologd_to_mozcdic
	# mecab-user-dict-seedを読み込む
	file = File.new($filename, "r")
		lines = file.read.split("\n")
	file.close

	l2 = []
	p = 0

	# neologd のエントリから読みと表記を取得
	lines.length.times do |i|
		# 表層形,左文脈ID,右文脈ID,コスト,品詞1,品詞2,品詞3,品詞4,品詞5,品詞6,\
		# 原形,読み,発音
		# little glee monster,1289,1289,2098,名詞,固有名詞,人名,一般,*,*,\
		# Little Glee Monster,リトルグリーモンスター,リトルグリーモンスター
		# リトルグリーモンスター,1288,1288,-1677,名詞,固有名詞,一般,*,*,*,\
		# Little Glee Monster,リトルグリーモンスター,リトルグリーモンスター
		# 新型コロナウィルス,1288,1288,4808,名詞,固有名詞,一般,*,*,*,\
		# 新型コロナウィルス,シンガタコロナウィルス,シンガタコロナウィルス
		# 新型コロナウイルス,1288,1288,4404,名詞,固有名詞,一般,*,*,*,\
		# 新型コロナウイルス,シンガタコロナウイルス,シンガタコロナウイルス

		s = lines[i].split(",")
		# 「読み」を取得
		yomi = s[11]
		# 「原形」を表記にする
		hyouki = s[10]

		# 読みのカタカナをひらがなに変換
		yomi = NKF.nkf("--hiragana -w -W", yomi)
		yomi = yomi.tr("ゐゑ", "いえ")

		# 読みがひらがな以外を含む場合はスキップ
		if yomi != yomi.scan(/[ぁ-ゔー]/).join
			next
		end

		# 名詞以外の場合はスキップ
		if s[4] != "名詞" ||
		# 「地域」をスキップ。地名は郵便番号ファイルから生成する
		s[6] == "地域" ||
		# 「名」をスキップ
		s[7] == "名"
			next
		end

		# [読み, 表記, コスト] の順に並べる
		l2[p] = [yomi, hyouki, s[3].to_i]
		p = p + 1
	end

	lines = l2.sort
	l2 = []

	# Mozcの品詞IDを取得
	idfile = File.new("../mozc/id.def", "r")
		id = idfile.read.split("\n")
	idfile.close

	# 「名詞,固有名詞,人名,一般,*,*」は優先度が低いので使わない。
	# 「名詞,固有名詞,一般,*,*,*」は後でフィルタリングする。
	id = id.grep(/\ 名詞,固有名詞,一般,\*,\*,\*,\*/)
	id = id[0].split(" ")[0]

	# Mozc形式で書き出す
	dicfile = File.new($dicname, "w")

	lines.length.times do |i|
		s1 = lines[i]
		s2 = lines[i - 1]

		# [読み..表記] が重複する場合はスキップ
		if s1[0..1] == s2[0..1]
			next
		end

		# コストがマイナスの場合は8000にする
		if s1[2] < 0
			s1[2] = 8000
		end

		# コストが10000を超える場合は10000にする
		if s1[2] > 10000
			s1[2] = 10000
		end

		# コストを 6000 < cost < 7000 に調整する
		s1[2] = 6000 + (s1[2] / 10)

		# [読み,id,id,コスト,表記] の順に並べる
		t = [s1[0], id, id, s1[2].to_s, s1[1]]
		dicfile.puts t.join("	")
	end

	dicfile.close
end


# ==============================================================================
# main
# ==============================================================================

require 'open-uri'
url = "https://github.com/neologd/mecab-ipadic-neologd/tree/master/seed"
neologdver = URI.open(url).read.split("mecab-user-dict-seed.")[1]
neologdver = neologdver.split(".csv.xz")[0]

`wget -nc https://github.com/neologd/mecab-ipadic-neologd/raw/master/seed/mecab-user-dict-seed.#{neologdver}.csv.xz`
`7z x -aos mecab-user-dict-seed.#{neologdver}.csv.xz`
$filename = "mecab-user-dict-seed.#{neologdver}.csv"
$dicname = "mozcdic-ut-neologd.txt"

convert_neologd_to_mozcdic