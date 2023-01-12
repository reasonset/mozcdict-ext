#!/bin/ruby

hash = {}

ARGF.each do |line|
  hash[line.chomp] ||= true
end

puts hash.keys