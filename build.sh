#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build packages
sdk_path="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun --sdk iphoneos clang -isysroot "$sdk_path" \
  -arch arm64 -arch arm64e -miphoneos-version-min=15.0 \
  -dynamiclib -fobjc-arc -fblocks -O2 -Wall -Wextra -Werror \
  -framework Foundation -framework UIKit -framework SpriteKit \
  -install_name /var/jb/Library/MobileSubstrate/DynamicLibraries/GlowCompanion.dylib \
  GlowCompanion.m -o build/GlowCompanion.dylib
codesign --force --sign - --timestamp=none build/GlowCompanion.dylib
codesign --verify --strict --verbose=2 build/GlowCompanion.dylib
xcrun lipo -verify_arch arm64 arm64e build/GlowCompanion.dylib
xcrun otool -L build/GlowCompanion.dylib
python3 package.py
