#!/bin/bash
# Builds Vitals and assembles Vitals.app in the project folder.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VITALS_VERSION:-1.0}"
BUILD="${VITALS_BUILD:-1}"

swift build -c release --product Vitals
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="Vitals.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/Vitals" "$APP/Contents/MacOS/Vitals"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Vitals</string>
    <key>CFBundleDisplayName</key>
    <string>Vitals</string>
    <key>CFBundleIdentifier</key>
    <string>local.vitals</string>
    <key>CFBundleExecutable</key>
    <string>Vitals</string>
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
