#!/bin/bash

set -euo pipefail

UNAME_S=$(uname -s)
VERSION=$(ruby -nle 'puts $1 if $_ =~ /^version: (.+)$/' pubspec.yaml)
ZIP=whispercppapp-macos-$VERSION.zip

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

setup() {
  if [ ! -f exe/ffmpeg ]; then
    echo "download: ffmpeg..."
    get_ffmpeg
  else
    echo "skip download: ffmpeg"
  fi

  if [ ! -f exe/whispercpp ]; then
    echo "build: whisper.cpp..."
    build_whispercpp
  else
    echo "skip build: whisper.cpp"
  fi

  flutter doctor
}

sign_binary() {
  codesign -f -s "Developer ID Application: Komuro Sunao (QMQNVXM7VQ)" --options=runtime "$1"
}

build() {
  case $UNAME_S in
  Darwin)
    sign_binary exe/ffmpeg
    sign_binary exe/whispercpp

    flutter build macos --release

    cd build/macos/Build/Products/Release
    rm -f "$ZIP"
    ditto -c -k --keepParent whispercppapp.app "$ZIP"
    open .
    cd -
    ;;
  esac
}

submit() {
  case $UNAME_S in
  Darwin)
    xcrun notarytool submit build/macos/Build/Products/Release/$ZIP \
      --apple-id "$APPLE_DEVELOPER_ID" \
      --password "$APPLE_DEVELOPER_PASSWORD" \
      --team-id "$APPLE_DEVELOPER_TEAM_ID" \
      --wait
    ;;
  esac
}

case "$1" in
  setup)
    setup
    ;;
  build)
    build
    ;;
  submit)
    submit
    ;;
  *)
    echo "unknown command: $1"
    ;;
esac
