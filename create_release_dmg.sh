#!/bin/bash
set -e

echo "➡️ Compiling Pasty via Xcode-beta..."
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -scheme Pasty -derivedDataPath build_output -configuration Release -destination 'generic/platform=macOS' ONLY_ACTIVE_ARCH=NO ARCHS="arm64 x86_64" build

./build_app.sh

echo "➡️ Creating DMG..."
rm -f Pasty.dmg

/opt/homebrew/bin/create-dmg \
  --volname "Pasty" \
  --background "/Users/jordanhill/.gemini/antigravity/brain/603a7ddc-9b59-4867-8453-af9fe2d8bd0c/dmg_background_1774574385428.png" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "Pasty.app" 150 190 \
  --hide-extension "Pasty.app" \
  --app-drop-link 450 190 \
  --no-internet-enable \
  --format UDBZ \
  "Pasty.dmg" \
  "Pasty.app/"

echo "✅ DMG Creation complete!"
