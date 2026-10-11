#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache build/dist
export CLANG_MODULE_CACHE_PATH="$PWD/build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/build/module-cache"
# Retain the original certificate and bundle identifier across the brand rename.
SIGNING_IDENTITY="${WHISPER_SIGNING_IDENTITY:-Whisper Bubble Personal Signing}"
if ! security find-certificate -c "$SIGNING_IDENTITY" >/dev/null 2>&1; then
  printf 'Run python3 scripts/setup-signing.py once before building.\n' >&2
  exit 1
fi
if pgrep -x WhisperBubble >/dev/null; then
  printf 'Quit Speaklet before building an update.\n' >&2
  exit 1
fi
# Build in a disposable directory. Only one app and installer remain in dist.
PACKAGE_STAGE=$(mktemp -d "$PWD/build/package.XXXXXX")
trap 'rm -rf "$PACKAGE_STAGE"' EXIT
APP_BUNDLE="$PACKAGE_STAGE/Speaklet.app"
for CPU_ARCH in arm64 x86_64; do
  swift build -c release --product WhisperBubble --triple "$CPU_ARCH-apple-macosx13.0" --disable-sandbox \
    --scratch-path "build/spm-$CPU_ARCH" --cache-path build/cache \
    --config-path build/config --security-path build/security
done
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
lipo -create build/spm-arm64/arm64-apple-macosx/release/WhisperBubble \
  build/spm-x86_64/x86_64-apple-macosx/release/WhisperBubble \
  -output "$APP_BUNDLE/Contents/MacOS/WhisperBubble"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
xcrun swift -module-cache-path "$PWD/build/module-cache" scripts/make-icon.swift "$PWD/build"
cp build/WhisperBubble.icns "$APP_BUNDLE/Contents/Resources/WhisperBubble.icns"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none --identifier local.whisperbubble.app --options runtime \
  --entitlements Resources/Entitlements.plist "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
plutil -lint "$APP_BUNDLE/Contents/Info.plist"
DMG_STAGE="$PACKAGE_STAGE/disk"
mkdir -p "$DMG_STAGE"
ditto "$APP_BUNDLE" "$DMG_STAGE/Speaklet.app"
if [ ! -L "$DMG_STAGE/Applications" ]; then ln -s /Applications "$DMG_STAGE/Applications"; fi
cp Resources/Install.txt "$DMG_STAGE/Read Me.txt"
hdiutil create -volname "Speaklet" -srcfolder "$DMG_STAGE" -ov -format UDZO \
  "$PACKAGE_STAGE/Speaklet.dmg"
hdiutil verify "$PACKAGE_STAGE/Speaklet.dmg"
(cd "$PACKAGE_STAGE" && shasum -a 256 Speaklet.dmg > SHA256SUMS.txt)
if pgrep -x WhisperBubble >/dev/null; then
  printf 'Speaklet was reopened. Quit it and rerun the build.\n' >&2
  exit 1
fi
if [ -e build/dist/Speaklet.app ]; then
  mv "build/dist/Speaklet.app" "$PACKAGE_STAGE/previous.app"
fi
mv "$APP_BUNDLE" build/dist/Speaklet.app
mv "$PACKAGE_STAGE/Speaklet.dmg" build/dist/Speaklet.dmg
mv "$PACKAGE_STAGE/SHA256SUMS.txt" build/dist/SHA256SUMS.txt
# Retire the generated outputs under the old name after the new package passes.
if [ -e "build/dist/Whisper Bubble.app" ]; then
  mv "build/dist/Whisper Bubble.app" "$PACKAGE_STAGE/previous-whisper.app"
fi
if [ -e build/dist/Whisper-Bubble.dmg ]; then
  mv build/dist/Whisper-Bubble.dmg "$PACKAGE_STAGE/previous-whisper.dmg"
fi
printf 'App: %s\nDMG: %s\n' "$PWD/build/dist/Speaklet.app" "$PWD/build/dist/Speaklet.dmg"
