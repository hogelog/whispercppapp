#!/bin/bash

set -euo pipefail

UNAME_S=$(uname -s)

get_ffmpeg() {
  case $UNAME_S in
  Darwin)
    wget --quiet --show-progress -O exe/ffmpeg.7z https://evermeet.cx/ffmpeg/ffmpeg-5.1.2.7z
    7z x -oexe exe/ffmpeg.7z
    rm exe/ffmpeg.7z
    ;;
  esac
}

build_whispercpp() {
  case $UNAME_S in
  Darwin)
	  cd whisper.cpp && make main && cp main ../exe/whispercpp && cd -
    ;;
  esac
}

if [ ! -f exe/ffmpeg ]; then
  get_ffmpeg
fi

if [ ! -f exe/whispercpp ]; then
  get_whispercpp
fi
