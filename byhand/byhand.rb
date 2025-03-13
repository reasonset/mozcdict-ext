#!/usr/bin/env ruby
require 'yaml'
require_relative './clsmap.rb'
require 'optparse'

ID_DEF = {}

$opts = {}
op = OptionParser.new
op.on("-W", "--exclude-containing-fullwidth-english")
op.parse!(ARGV, into: $opts)

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

  process_cls(base, yomi, cls)
end