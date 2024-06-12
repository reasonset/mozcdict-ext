#!/usr/bin/env ruby
require 'yaml'

ID_DEF = {}
ID_MAP = YAML.load(File.read "def.yaml")

# Load Mozc ID definition.
File.open(ENV["MOZC_ID_FILE"], "r") do |f|
  f.each do |line|
    id, expr = line.chomp.split(" ", 2)
    ID_DEF[expr] = id
  end
end

#コストは暫定で一律6500に設定
COST = 6500

File.foreach("dict.csv") do |line|
  next if line =~ /^\s*\#/
  # 表記 読み 品詞
  base, yomi, cls = line.chomp.split("\t")

  # byhand品詞からMozc品詞への変換
  # 複数のMozc品詞にマップされることもある
  clses = ID_MAP[cls]
  clses ||= [cls]
  clses.each do |cls|
    # Mozcの品詞IDを取得する
    id = ID_DEF[cls]

    # 出力
    puts [yomi, id, id, COST, base].join("\t")
  end
end