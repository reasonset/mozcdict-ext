#!/bin/zsh

if [[ ! -e ./neologd.rb ]]
then
  print "Run this script on same directory as mkdict.zsh" >&2
  exit 1
fi

if [[ -e upsttream ]]
then
  (
    cd upstream
    git pull
  )
else
  git clone 'https://github.com/neologd/mecab-ipadic-neologd.git' upstream
fi

