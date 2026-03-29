#!/bin/bash
set -e

echo "➡️ Creating Pasty.app container..."
APP_DIR="Pasty.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

echo "➡️ Copying executable and SwiftPM bundles..."
cp build_output/Build/Products/Release/Pasty "$APP_DIR/Contents/MacOS/"
if [ -d "build_output/Build/Products/Release/Pasty_Pasty.bundle" ]; then
    cp -R build_output/Build/Products/Release/Pasty_Pasty.bundle "$APP_DIR/Contents/Resources/"
fi

# Link AppIcon payload explicitly
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

echo "➡️ Generating signed Info.plist..."
cat << 'PLIST' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Pasty</string>
    <key>CFBundleIdentifier</key>
    <string>com.jordan.pasty</string>
    <key>CFBundleName</key>
    <string>Pasty</string>
    <key>CFBundleVersion</key>
    <string>4</string>
    <key>CFBundleShortVersionString</key>
    <string>3.1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
PLIST

echo "➡️ Signing the application bundle to unlock macOS Accessibility APIs..."
codesign --force --deep --sign - "$APP_DIR"

echo "➡️ Packaging complete. Pasty.app is ready."
