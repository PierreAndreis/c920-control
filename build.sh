#!/bin/zsh
# Builds C920 Control.app into ./build. Usage: ./build.sh [--run | --install]
set -euo pipefail
cd "$(dirname "$0")"
APP="build/C920 Control.app"
BIN="$APP/Contents/MacOS"
rm -rf build && mkdir -p "$BIN" "$APP/Contents/Resources" build/obj

clang -fobjc-arc -O2 -c Sources/UVC/UVCDevice.m -o build/obj/UVCDevice.o
swiftc -O -swift-version 5 -parse-as-library \
  -import-objc-header Sources/App/Bridging.h -I Sources/UVC \
  -framework SwiftUI -framework AVFoundation -framework IOKit -framework IOUSBHost \
  Sources/App/*.swift build/obj/UVCDevice.o -o "$BIN/C920Control"

cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "built: $APP"
[[ "${1:-}" == "--run" ]] && open "$APP"
if [[ "${1:-}" == "--install" ]]; then
  pkill -x C920Control || true
  rm -rf "$HOME/Applications/C920 Control.app"
  cp -R "$APP" "$HOME/Applications/"
  open "$HOME/Applications/C920 Control.app"
  echo "installed and launched: ~/Applications/C920 Control.app"
fi
