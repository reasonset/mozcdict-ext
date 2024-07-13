#!/bin/zsh
setopt EXTENDED_GLOB
setopt BARE_GLOB_QUAL

if [[ ! -e ./neologd.rb ]]
then
  print "Run this script on same directory as mkdict.zsh" >&2
  exit 1
fi

if [[ ! -e "upstream/seed" ]]
then
  git submodule init
  git submodule sync
  git submodule update
fi

mkdir -p src/seed

xz -k -d -c upstream/seed/mecab-*([1]) > src/seed/user-dict-seed.csv

ruby ./neologd.rb $@
