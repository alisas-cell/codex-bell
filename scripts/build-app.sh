#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Codex Bell.app can only be assembled on macOS." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
DIST="$ROOT/dist"
APP="$DIST/Codex Bell.app"
MACOS="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"
ICON_SRC="$ROOT/assets/CodexBellIcon.png"
ICON_NAME="CodexBell"

rm -rf "$APP" "$DIST/$ICON_NAME.iconset"
mkdir -p "$MACOS" "$RESOURCES"

cd "$ROOT"
swift build -c release --product CodexBell
swift build -c release --product codex-bell-hook
BIN_DIR="$(swift build -c release --show-bin-path)"

cp "$BIN_DIR/CodexBell" "$MACOS/CodexBell"
cp "$BIN_DIR/codex-bell-hook" "$MACOS/codex-bell-hook"
chmod +x "$MACOS/CodexBell" "$MACOS/codex-bell-hook"
cp "$ROOT/Sources/CodexBellApp/Resources/CodexBellChime.wav" "$RESOURCES/CodexBellChime.wav"

if [[ -f "$ICON_SRC" ]] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
  ICONSET="$DIST/$ICON_NAME.iconset"
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -z $size $size "$ICON_SRC" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size*2)) $((size*2)) "$ICON_SRC" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  cp "$ICON_SRC" "$ICONSET/icon_512x512@2x.png"
  iconutil -c icns "$ICONSET" -o "$RESOURCES/$ICON_NAME.icns"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleDisplayName</key><string>Codex Bell</string>
  <key>CFBundleExecutable</key><string>CodexBell</string>
  <key>CFBundleIdentifier</key><string>com.codexbell.app</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>Codex Bell</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CodexBellSupportDirectoryName</key><string>Codex Bell</string>
  <key>LSMultipleInstancesProhibited</key><true/>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleIconFile</key><string>$ICON_NAME</string>
</dict>
</plist>
PLIST

IDENTITY="${CODE_SIGN_IDENTITY:--}"
if command -v codesign >/dev/null 2>&1; then
  if [[ "$IDENTITY" == "-" ]]; then
    codesign --force --options runtime --timestamp=none --sign - "$MACOS/codex-bell-hook"
    codesign --force --options runtime --timestamp=none --sign - "$MACOS/CodexBell"
    codesign --force --options runtime --timestamp=none --sign - "$APP"
  else
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$MACOS/codex-bell-hook"
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$MACOS/CodexBell"
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
  fi
fi

echo "$APP"
