#!/bin/bash
set -e

echo "➡️ Creating Pasty.app container in /tmp to bypass iCloud FileProvider locks..."
rm -rf /tmp/Pasty_Build
mkdir -p /tmp/Pasty_Build
APP_DIR="/tmp/Pasty_Build/Pasty.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
mkdir -p "$APP_DIR/Contents/Frameworks"

echo "➡️ Copying executable (using ditto to strip metadata)..."
ditto --norsrc --noextattr build_output/Build/Products/Release/Pasty "$APP_DIR/Contents/MacOS/Pasty"

if [ -d "build_output/Build/Products/Release/Pasty_Pasty.bundle" ]; then
    echo "➡️ Copying SwiftPM bundle (using ditto)..."
    ditto --norsrc --noextattr build_output/Build/Products/Release/Pasty_Pasty.bundle "$APP_DIR/Contents/Resources/Pasty_Pasty.bundle"
    echo "➡️ Extracting Native Asset Catalog to Global Scope..."
    cp build_output/Build/Products/Release/Pasty_Pasty.bundle/Contents/Resources/Assets.car "$APP_DIR/Contents/Resources/Assets.car" 2>/dev/null || true
fi

echo "➡️ Injecting Framework rpath..."
install_name_tool -add_rpath @executable_path/../Frameworks "$APP_DIR/Contents/MacOS/Pasty" 2>/dev/null || true

# Embed Sparkle.framework
if [ -d "build_output/Build/Products/Release/Sparkle.framework" ]; then
    echo "➡️ Embedding Sparkle.framework..."
    mkdir -p "$APP_DIR/Contents/Frameworks"
    ditto --norsrc --noextattr build_output/Build/Products/Release/Sparkle.framework "$APP_DIR/Contents/Frameworks/Sparkle.framework"
fi

# Link AppIcon payload explicitly
if [ -f "AppIcon.icns" ]; then
    echo "➡️ Copying app icon..."
    xattr -c AppIcon.icns 2>/dev/null || true
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
    <string>6</string>
    <key>CFBundleShortVersionString</key>
    <string>3.3</string>
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
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Pasty uses accessibility to register global keyboard shortcuts and paste into other apps.</string>
    <key>SUFeedURL</key>
    <string>https://pastyapp.github.io/pasty-distribution-repo/appcast.xml</string>
</dict>
</plist>
PLIST

echo "➡️ Nuclear xattr strip (every file in the bundle)..."
find "$APP_DIR" -exec xattr -d com.apple.FinderInfo {} \; 2>/dev/null || true
find "$APP_DIR" -exec xattr -d com.apple.ResourceFork {} \; 2>/dev/null || true
find "$APP_DIR" -type l -exec xattr -d -s com.apple.FinderInfo {} \; 2>/dev/null || true
xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
xattr -d com.apple.ResourceFork "$APP_DIR" 2>/dev/null || true
dot_clean -n "$APP_DIR" || true

echo "➡️ Verifying clean (no extended attributes)..."
REMAINING=$(xattr -lr "$APP_DIR" 2>/dev/null | wc -l)
echo "   Extended attributes remaining: $REMAINING"

echo "➡️ Signing with Developer ID Application certificate (Hardened Runtime)..."
SIGN_ID="Developer ID Application: Jordan Hill (286XQ7PY4A)"

# Deep-sign Sparkle framework internals (XPC services, Updater.app, Autoupdate binary)
# Must sign from innermost to outermost
if [ -d "$APP_DIR/Contents/Frameworks/Sparkle.framework" ]; then
    echo "   Signing Sparkle internals..."
    
    # Sign all XPC services
    find "$APP_DIR/Contents/Frameworks/Sparkle.framework" -name "*.xpc" -type d | while read -r xpc; do
        xattr -rc "$xpc"
        codesign --force --deep --options runtime --timestamp --sign "$SIGN_ID" "$xpc"
    done
    
    # Sign Updater.app
    find "$APP_DIR/Contents/Frameworks/Sparkle.framework" -name "*.app" -type d | while read -r app; do
        xattr -rc "$app"
        codesign --force --deep --options runtime --timestamp --sign "$SIGN_ID" "$app"
    done
    
    # Sign the Autoupdate binary directly
    find "$APP_DIR/Contents/Frameworks/Sparkle.framework" -name "Autoupdate" -type f | while read -r binary; do
        codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$binary"
    done
    
    # Sign the framework itself
    xattr -rc "$APP_DIR/Contents/Frameworks/Sparkle.framework"
    codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP_DIR/Contents/Frameworks/Sparkle.framework"
fi

# Sign other inner bundles
find "$APP_DIR/Contents" \( -name "*.bundle" -o -name "*.dylib" \) | while read -r nested; do
    xattr -rc "$nested"
    codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$nested"
done

# Final strip before outer sign
xattr -rc "$APP_DIR"
# Sign outer app
codesign --force --options runtime --timestamp --sign "$SIGN_ID" --entitlements "Pasty/Pasty.entitlements" "$APP_DIR"

echo "➡️ Packaging complete. Pasty.app is ready in TMP."
rm -rf Pasty.app
cp -R "/tmp/Pasty_Build/Pasty.app" "Pasty.app"
