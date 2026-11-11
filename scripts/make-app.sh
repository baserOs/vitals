#!/bin/bash
# Builds Vitalis and assembles Vitalis.app in the project folder.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VITALIS_VERSION:-1.0}"
BUILD="${VITALIS_BUILD:-1}"

swift build -c release --product Vitalis
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="Vitalis.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/Vitalis" "$APP/Contents/MacOS/Vitalis"

# The icon: every size macOS asks for, scaled from the one drawing.
mkdir -p "$APP/Contents/Resources"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" Assets/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z "$DOUBLE" "$DOUBLE" Assets/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$ICONSET")"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Vitalis</string>
    <key>CFBundleDisplayName</key>
    <string>Vitalis</string>
    <key>CFBundleIdentifier</key>
    <string>local.vitals</string>
    <key>CFBundleExecutable</key>
    <string>Vitalis</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc signature: enough to run on the Mac that built or downloaded it.
codesign --force --sign - "$APP"
echo "Built $APP"
