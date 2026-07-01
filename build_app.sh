#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/ProjectBar.app"
BUILD_DIR="${PROJECTBAR_BUILD_DIR:-/private/tmp/projectbar-build-$UID}"
EXEC="$BUILD_DIR/release/ProjectBar"

cd "$ROOT"
rm -rf "$BUILD_DIR"
swift build -c release --scratch-path "$BUILD_DIR"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$EXEC" "$APP/Contents/MacOS/ProjectBar"
cp "$ROOT/GitSync.png" "$APP/Contents/Resources/GitSync.png"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>ProjectBar</string>
  <key>CFBundleIdentifier</key>
  <string>local.projectbar</string>
  <key>CFBundleName</key>
  <string>ProjectBar</string>
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
