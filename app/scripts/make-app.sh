#!/bin/sh
# Builds Sophia.app from the Swift package. Needs only the Xcode Command Line Tools.
# Usage: scripts/make-app.sh [debug|release]   (default: release)
# Output: build/Sophia.app
set -eu
cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
swift build -c "$CONFIG" --product Sophia
swift build -c "$CONFIG" --product sophia-mcp
BIN="$(swift build -c "$CONFIG" --show-bin-path)"

APP=build/Sophia.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Sophia" "$BIN/sophia-mcp" "$APP/Contents/MacOS/"
cp ../SOPHIA.md "$APP/Contents/Resources/SOPHIA.md"
cp Resources/Sophia.icns "$APP/Contents/Resources/Sophia.icns"
# The reader finds its resource bundle in Contents/Resources when packaged.
cp -R "$BIN/Sophia_SophiaReader.bundle" "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Sophia</string>
  <key>CFBundleDisplayName</key><string>Sophia</string>
  <key>CFBundleIdentifier</key><string>com.sophia.notebook</string>
  <key>CFBundleExecutable</key><string>Sophia</string>
  <key>CFBundleIconFile</key><string>Sophia</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST
# Ad-hoc signature for running locally. Distribution needs a Developer ID and notarization.
codesign --force --deep --sign - "$APP"
echo "Built $APP"
