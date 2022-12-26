#!/bin/bash

set -euo pipefail

UNAME_S=$(uname -s)
VERSION=$(ruby -nle 'puts $1 if $_ =~ /^version: (.+)$/' pubspec.yaml)

get_ffmpeg() {
  case $UNAME_S in
  Darwin)
    wget --quiet --show-progress -O exe/ffmpeg.7z https://evermeet.cx/ffmpeg/ffmpeg-5.1.2.7z
    7z x -oexe exe/ffmpeg.7z
    rm exe/ffmpeg.7z
    ;;
  esac
}

get_whispercpp() {
  case $UNAME_S in
  Darwin)
	  cd whisper.cpp
	  make clean && make main && cp main main.arm64
	  make clean && arch -x86_64 make main && cp main main.x86_64
	  lipo -create -output ../exe/whispercpp main.arm64 main.x86_64
	  rm main.{arm64,x86_64}
	  make clean
	  cd -
    ;;
  esac
}

build() {
  case $UNAME_S in
  Darwin)
    flutter build macos
    cd build/macos/Build/Products/Release
    zip -ry whispercppapp-macos-$VERSION.zip whispercppapp.app
    cd -
    ;;
  esac
}

if [ ! -f exe/ffmpeg ]; then
  get_ffmpeg
fi

if [ ! -f exe/whispercpp ]; then
  get_whispercpp
fi

build
