#!/bin/bash
set -e

# 4K Resolution
W=3840
H=2160

LOGO="website/assets/images/logo_round.png"
APP_UI="website/assets/images/hotbar-pinned.png"
OUT="/Users/jordanhill/Desktop/Pastry/Pasty_Thumbnail_4K.jpg"

echo "🎨 Compositing Professional 4K Thumbnail..."

# Build the filtergraph
# 0: Color background
# 1: Logo
# 2: App UI
# Add a subtle radial gradient (vignette) to the background to make it modern
# Then overlay the text and images.

./ffmpeg -y -nostdin \
  -f lavfi -i "color=c=0x0a0a0c:s=${W}x${H}" \
  -i "$LOGO" \
  -i "$APP_UI" \
  -filter_complex " \
    [1:v]scale=-1:600[logo_scaled]; \
    [2:v]scale=-1:1600[app_scaled]; \
    [0:v][logo_scaled]overlay=180:240[bg1]; \
    [bg1][app_scaled]overlay=W-w-100:(H-h)/2[bg_final]; \
    [bg_final]drawtext=text='Pasty v3.1':fontsize=280:fontcolor=white:x=200:y=1000:fontfile=/System/Library/Fonts/SFNS-Bold.ttf, \
    drawtext=text='The Native macOS Clipboard.':fontsize=110:fontcolor=0x95A7F1:x=220:y=1360:fontfile=/System/Library/Fonts/SFNS.ttf, \
    drawtext=text='120Hz ProMotion Engine':fontsize=95:fontcolor=0x4ADE80:x=220:y=1560:fontfile=/System/Library/Fonts/SFNS.ttf \
  " \
  -vframes 1 \
  -q:v 2 \
  "$OUT" 2>/dev/null

echo "✅ Created Beautiful 4K Thumbnail at $OUT"
