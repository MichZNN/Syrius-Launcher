#!/usr/bin/env bash
# Packages the release build into build/dmg/SyriusLauncher-<version>.dmg.
#
# Run `flutter build macos --release` first.
#
# Optional environment variables:
#   SIGN_IDENTITY      "Developer ID Application: Name (TEAMID)". When set, the
#                      app is signed with the hardened runtime and the dmg is
#                      signed too. Without it the app keeps Flutter's ad-hoc
#                      signature (fine for personal use, Gatekeeper will warn).
#   NOTARY_APPLE_ID, NOTARY_TEAM_ID, NOTARY_PASSWORD
#                      When all three are set (and SIGN_IDENTITY), the dmg is
#                      notarized by Apple and the ticket is stapled.
set -euo pipefail

cd "$(dirname "$0")/.."

APP="build/macos/Build/Products/Release/Syrius Launcher.app"
ENTITLEMENTS="macos/Runner/Release.entitlements"
OUT_DIR="build/dmg"

if [[ ! -d "$APP" ]]; then
  echo "error: $APP not found. Run: flutter build macos --release" >&2
  exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="$OUT_DIR/SyriusLauncher-$VERSION.dmg"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  echo "==> Signing with: $SIGN_IDENTITY"
  # Sign nested code first (inside-out), then the app itself.
  while IFS= read -r -d '' item; do
    codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$item"
  done < <(find "$APP/Contents/Frameworks" -depth \( -name '*.framework' -o -name '*.dylib' \) -print0)
  codesign --force --timestamp --options runtime \
    --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP"
fi
codesign --verify --deep --strict "$APP"

echo "==> Creating $DMG"
mkdir -p "$OUT_DIR"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Syrius Launcher.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Syrius Launcher" -srcfolder "$STAGE" \
  -fs HFS+ -format UDZO -imagekey zlib-level=9 "$DMG" >/dev/null

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi

if [[ -n "${SIGN_IDENTITY:-}" && -n "${NOTARY_APPLE_ID:-}" && -n "${NOTARY_TEAM_ID:-}" && -n "${NOTARY_PASSWORD:-}" ]]; then
  echo "==> Notarizing (this can take a few minutes)"
  xcrun notarytool submit "$DMG" \
    --apple-id "$NOTARY_APPLE_ID" --team-id "$NOTARY_TEAM_ID" \
    --password "$NOTARY_PASSWORD" --wait
  xcrun stapler staple "$DMG"
fi

shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "==> Done: $DMG"
