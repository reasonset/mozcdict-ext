#!/usr/bin/env ruby
require 'csv'

FILES = {}

begin
  ["src/core_lex.csv", "src/notcore_lex.csv"].each do |source_file|
    CSV.foreach(source_file) do |row|
      head_trie, lid, rid, cost, head_anal, cls1, cls2, cls3, cls4, cls5, cls6, kana, normal, did, dtype, adiv, bdiv = *row

      clsexpr = [cls1, cls2, cls3, cls4, cls5, cls6].join(",")
      if !FILES[clsexpr]
        FILES[clsexpr] = File.open("../.dev.reference/sudachi-cls/#{clsexpr}", "a")
      end

      FILES[clsexpr].puts head_anal
    end
  end
ensure
  FILES.each do |k, v|
    v.close
  end
end