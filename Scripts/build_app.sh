#!/bin/zsh
# Builds Idle.app — a proper macOS .app bundle from the SwiftPM target.
# Usage:
#   ./Scripts/build_app.sh             # builds Idle.app in build/
#   ./Scripts/build_app.sh --install   # also copies it to /Applications
#   ./Scripts/build_app.sh --dmg       # also packages Idle.dmg for distribution
#   ./Scripts/build_app.sh --notarize  # signs with Developer ID + notarizes
#                                      # (requires APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD env vars)

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
BUNDLE_NAME="Idle"
BUNDLE_ID="ai.ashlr.idle"
VERSION="0.8.1"
BUILD_VERSION="0.8.1"

OUT_DIR="$ROOT/build"
APP_PATH="$OUT_DIR/$BUNDLE_NAME.app"

echo "==> swift build -c release"
swift build -c release

BIN_PATH="$ROOT/.build/release/$BUNDLE_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
    echo "Error: binary not found at $BIN_PATH" >&2
    exit 1
fi

echo "==> Assembling $APP_PATH"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

cp "$BIN_PATH" "$APP_PATH/Contents/MacOS/$BUNDLE_NAME"
chmod +x "$APP_PATH/Contents/MacOS/$BUNDLE_NAME"

cat >"$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$BUNDLE_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$BUNDLE_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$BUNDLE_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_VERSION</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
</dict>
</plist>
PLIST

FLAGS="${@:-}"

if [[ "$FLAGS" == *"--notarize"* ]]; then
    : "${APPLE_ID:?APPLE_ID env var required for notarization}"
    : "${APPLE_TEAM_ID:?APPLE_TEAM_ID env var required}"
    : "${APPLE_APP_PASSWORD:?APPLE_APP_PASSWORD env var required (app-specific password from appleid.apple.com)}"
    echo "==> Codesigning with Developer ID Application: $APPLE_TEAM_ID"
    codesign --force --deep --options runtime --timestamp \
        --sign "Developer ID Application" "$APP_PATH"
else
    echo "==> Ad-hoc codesigning (no Developer ID; replace with --notarize for distribution)"
    codesign --force --deep --sign - "$APP_PATH" || true
fi

echo "==> Built $APP_PATH"

if [[ "$FLAGS" == *"--install"* ]]; then
    DEST="/Applications/$BUNDLE_NAME.app"
    echo "==> Installing to $DEST"
    rm -rf "$DEST"
    cp -R "$APP_PATH" "$DEST"
    echo "==> Installed. Launch with: open $DEST"
fi

if [[ "$FLAGS" == *"--dmg"* || "$FLAGS" == *"--notarize"* ]]; then
    DMG_PATH="$OUT_DIR/$BUNDLE_NAME.dmg"
    echo "==> Packaging $DMG_PATH"
    rm -f "$DMG_PATH"
    # Staging folder so the DMG only shows the .app + an Applications symlink.
    STAGING="$OUT_DIR/dmg-staging"
    rm -rf "$STAGING"
    mkdir -p "$STAGING"
    cp -R "$APP_PATH" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"
    hdiutil create -volname "$BUNDLE_NAME" -srcfolder "$STAGING" \
        -ov -format UDZO "$DMG_PATH" >/dev/null
    rm -rf "$STAGING"
    echo "==> Built $DMG_PATH"
fi

if [[ "$FLAGS" == *"--notarize"* ]]; then
    echo "==> Submitting to Apple notary service"
    xcrun notarytool submit "$OUT_DIR/$BUNDLE_NAME.dmg" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_PASSWORD" \
        --wait
    echo "==> Stapling ticket"
    xcrun stapler staple "$OUT_DIR/$BUNDLE_NAME.dmg"
    xcrun stapler staple "$APP_PATH"
    echo "==> Notarized + stapled."
fi
