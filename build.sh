#!/bin/bash
#
# build.sh — Build "Claude Tracker.app" and package it for sharing,
# using only the Xcode Command Line Tools (no full Xcode required).
#
# Outputs (in ./dist):
#   Claude Tracker.app    — the app bundle
#   Claude-Tracker.dmg    — drag-to-Applications disk image (share this)
#   Claude-Tracker.zip    — zipped app bundle (alternative to the dmg)
#
# Usage:  ./build.sh
#
set -euo pipefail

# ---- Metadata (kept in sync with the Xcode project) -------------------------
APP_NAME="Claude Tracker"
BUNDLE_ID="com.abhishek.ClaudeTracker"
VERSION="1.0.0"
BUILD="9"
MIN_MACOS="14.0"

# ---- Paths ------------------------------------------------------------------
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/Claude Tracker"
BUILD_DIR="$ROOT/build"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
MACOS_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"

SDK="$(xcrun --sdk macosx --show-sdk-path)"

echo "==> Cleaning"
rm -rf "$BUILD_DIR" "$APP"
mkdir -p "$BUILD_DIR" "$MACOS_DIR" "$RES_DIR"

# ---- 1. Collect sources -----------------------------------------------------
SWIFT_FILES=()
while IFS= read -r -d '' f; do SWIFT_FILES+=("$f"); done \
  < <(find "$SRC" -name '*.swift' -print0)
echo "==> Compiling ${#SWIFT_FILES[@]} Swift files"

# ---- 2. Compile a universal (arm64 + x86_64) binary -------------------------
compile_arch() {
  local arch="$1" out="$2"
  swiftc \
    -sdk "$SDK" \
    -target "${arch}-apple-macos${MIN_MACOS}" \
    -O -whole-module-optimization \
    -framework AppKit -framework SwiftUI -framework Combine \
    -o "$out" \
    "${SWIFT_FILES[@]}"
}

ARCHS=()
compile_arch "arm64" "$BUILD_DIR/app-arm64" && ARCHS+=("$BUILD_DIR/app-arm64")
if compile_arch "x86_64" "$BUILD_DIR/app-x86_64" 2>/dev/null; then
  ARCHS+=("$BUILD_DIR/app-x86_64")
  echo "    built universal (arm64 + x86_64)"
else
  echo "    x86_64 slice failed — shipping arm64-only (Apple Silicon)"
fi
lipo -create "${ARCHS[@]}" -output "$MACOS_DIR/$APP_NAME"

# ---- 3. App icon (.icns) from the asset catalog PNGs ------------------------
ICONSET="$BUILD_DIR/AppIcon.iconset"
ICON_SRC="$SRC/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$ICONSET"
cp "$ICON_SRC/16.png"   "$ICONSET/icon_16x16.png"
cp "$ICON_SRC/32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ICON_SRC/32.png"   "$ICONSET/icon_32x32.png"
cp "$ICON_SRC/64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ICON_SRC/128.png"  "$ICONSET/icon_128x128.png"
cp "$ICON_SRC/256.png"  "$ICONSET/icon_128x128@2x.png"
cp "$ICON_SRC/256.png"  "$ICONSET/icon_256x256.png"
cp "$ICON_SRC/512.png"  "$ICONSET/icon_256x256@2x.png"
cp "$ICON_SRC/512.png"  "$ICONSET/icon_512x512.png"
cp "$ICON_SRC/1024.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$RES_DIR/AppIcon.icns"
echo "==> Built AppIcon.icns"

# ---- 4. Info.plist (placeholders resolved) ----------------------------------
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleExecutable</key><string>$APP_NAME</string>
	<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>CFBundleName</key><string>$APP_NAME</string>
	<key>CFBundleDisplayName</key><string>$APP_NAME</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>$VERSION</string>
	<key>CFBundleVersion</key><string>$BUILD</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundleIconName</key><string>AppIcon</string>
	<key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
	<key>LSUIElement</key><true/>
	<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
	<key>NSHumanReadableCopyright</key><string>Copyright © 2025. All rights reserved.</string>
	<key>NSSupportsAutomaticTermination</key><true/>
	<key>NSSupportsSuddenTermination</key><false/>
</dict>
</plist>
PLIST
echo "==> Wrote Info.plist"

# ---- 5. Ad-hoc code signature (lets it run locally) -------------------------
codesign --force --deep --sign - "$APP"
echo "==> Ad-hoc signed"

# ---- 6. Package: .zip and .dmg ----------------------------------------------
echo "==> Packaging"
rm -f "$DIST/Claude-Tracker.zip" "$DIST/Claude-Tracker.dmg"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/Claude-Tracker.zip"

DMG_STAGE="$BUILD_DIR/dmg"
rm -rf "$DMG_STAGE"; mkdir -p "$DMG_STAGE"
cp -R "$APP" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGE" \
  -ov -format UDZO "$DIST/Claude-Tracker.dmg" >/dev/null

echo
echo "==> Done. Artifacts in ./dist:"
ls -1sh "$DIST" | sed 's/^/    /'
