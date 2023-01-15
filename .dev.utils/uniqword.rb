#!/usr/bin/env ruby

# 品詞を含めて重複する語を除外する。
# このスクリプトを実行するには辞書全体を収納できるメモリが必要になる。
# ARGFから読んでSTDOUTに吐く。
# 後から出た語が除外されるため、優先度を信頼したい辞書を先に指定するのがおすすめ。

REMEMBER = {}

ARGF.each do |line|
  yomi, id1, id2, cost, base = line.chomp.split("\t")
  expr = [yomi, id1, base].join(",")
  if REMEMBER[expr]
    STDERR.puts("#{expr} is duplicated")
    next
  else
    REMEMBER[expr] = true
    puts line
  end
end