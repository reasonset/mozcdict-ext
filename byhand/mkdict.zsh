#!/bin/zsh
setopt EXTENDED_GLOB
setopt BARE_GLOB_QUAL

if [[ ! -e ./byhand.rb ]]
then
  print "Run this script on same directory as mkdict.zsh" >&2
  exit 1
fi

ruby byhand.rb $@