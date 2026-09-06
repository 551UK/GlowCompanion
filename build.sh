#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build packages
sdk_path="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun --sdk iphoneos clang -isysroot "$sdk_path" \
  -arch arm64 -arch arm64e -miphoneos-version-min=15.0 \
  -dynamiclib -fobjc-arc -fblocks -O2 -Wall -Wextra -Werror \
  -framework Foundation -framework UIKit -framework SpriteKit -framework CoreGraphics \
  -install_name /var/jb/Library/MobileSubstrate/DynamicLibraries/GlowIconPosition.dylib \
  GlowIconPosition.m -o build/GlowIconPosition.dylib
codesign --force --sign - --timestamp=none build/GlowIconPosition.dylib
codesign --verify --strict --verbose=2 build/GlowIconPosition.dylib
xcrun lipo build/GlowIconPosition.dylib -verify_arch arm64 arm64e
xcrun otool -L build/GlowIconPosition.dylib
python3 package.py
