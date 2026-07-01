#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/GitBar.app"
BUILD_DIR="${GITBAR_BUILD_DIR:-/private/tmp/gitbar-build-$UID}"
EXEC="$BUILD_DIR/release/GitBar"

cd "$ROOT"
rm -rf "$BUILD_DIR"
swift build -c release --scratch-path "$BUILD_DIR"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$EXEC" "$APP/Contents/MacOS/GitBar"
cp "$ROOT/GitBar.png" "$APP/Contents/Resources/GitBar.png"
cp "$ROOT/GitBar.icns" "$APP/Contents/Resources/GitBar.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>GitBar</string>
  <key>CFBundleIconFile</key>
  <string>GitBar</string>
  <key>CFBundleIdentifier</key>
  <string>local.gitbar</string>
  <key>CFBundleName</key>
  <string>GitBar</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "Built $APP"
