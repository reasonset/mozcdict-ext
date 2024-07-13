#!/bin/zsh

latest_date=$(curl -s 'http://sudachi.s3-website-ap-northeast-1.amazonaws.com/sudachidict-raw/' | grep -o '<td>[0-9]*</td>' | grep -o '[0-9]*' | sort -n | tail -n 1)

if [[ -e upstream ]]
then
  rm -rf upstream
fi
mkdir upstream

if [[ -e src ]]
then
  rm -rf src
fi
mkdir src

#print http://sudachi.s3-website-ap-northeast-1.amazonaws.com/sudachidict-raw/20230110/core_lex.zip
#print http://sudachi.s3-website-ap-northeast-1.amazonaws.com/sudachidict-raw/$date/core_lex.zip

if [[ ! -e upstream/core_lex_${latest_date}.zip ]]
then
  curl -s "http://sudachi.s3-website-ap-northeast-1.amazonaws.com/sudachidict-raw/$latest_date/core_lex.zip" -o upstream/core_lex_${latest_date}.zip
fi

if [[ ! -e upstream/notcore_lex_${latest_date}.zip ]]
then
  curl -s "http://sudachi.s3-website-ap-northeast-1.amazonaws.com/sudachidict-raw/$latest_date/notcore_lex.zip" -o upstream/notcore_lex.zip
fi

(
  cd upstream
  for i in *_${latest_date}.zip
  do
    unzip -d ../src $i
  done
) > /dev/null

ruby sudachi.rb $@
