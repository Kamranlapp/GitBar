#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/GitBar.app"
PKG="$ROOT/GitBarInstaller.pkg"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gitbar-installer.XXXXXX")"
STAGE_DIR="$TMP_DIR/payload"
COMPONENT_PKG="$TMP_DIR/GitBar-component.pkg"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cd "$ROOT"
"$ROOT/build_app.sh"
xattr -cr "$APP"
mkdir -p "$STAGE_DIR"
ditto --norsrc --noextattr "$APP" "$STAGE_DIR/GitBar.app"

rm -f "$ROOT"/GitBar*.pkg "$COMPONENT_PKG"
export COPYFILE_DISABLE=1
pkgbuild \
  --root "$STAGE_DIR" \
  --install-location "/Applications" \
  --identifier "local.gitbar" \
  --version "0.1.0" \
  "$COMPONENT_PKG"

productbuild \
  --package "$COMPONENT_PKG" \
  "$PKG"

rm -rf "$APP"
echo "Built $PKG"
