#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
if [[ "${1:-}" != "--skip-build" ]]; then
  "$ROOT/scripts/build-app.sh"
fi
APP="$ROOT/dist/Codex Bell.app"
ZIP_NAME="Codex-Bell-macOS-v$VERSION.zip"
ZIP="$ROOT/dist/$ZIP_NAME"
CHECKSUM="$ROOT/dist/Codex-Bell-macOS-v$VERSION.sha256"

codesign --verify --deep --strict --verbose=2 "$APP"
rm -f "$ZIP" "$CHECKSUM"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
(
  cd "$ROOT/dist"
  LC_ALL=C shasum -a 256 "$ZIP_NAME" > "$(basename "$CHECKSUM")"
)
printf '%s\n%s\n' "$ZIP" "$CHECKSUM"
