#!/bin/bash
set -e

cd /Users/jordanhill/Desktop/Pastry
FFMPEG="./ffmpeg"
OUT="Pasty_Promo.mp4"
W=1920
H=1080

echo "➡️ Step 1/5: Extracting best clips from recordings..."

# Extract the best 8s from the hotkey features video (the code view expand moment)
$FFMPEG -y -ss 10 -t 8 -i "Records/video shwing off hotkey bar features.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=black" \
  -c:v libx264 -crf 20 -preset fast -an -r 30 /tmp/clip_features_1.mp4

# Extract another moment - scrolling/navigating  
$FFMPEG -y -ss 30 -t 8 -i "Records/video shwing off hotkey bar features.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=black" \
  -c:v libx264 -crf 20 -preset fast -an -r 30 /tmp/clip_features_2.mp4

# Extract the pin/expand moment
$FFMPEG -y -ss 55 -t 8 -i "Records/video shwing off hotkey bar features.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=black" \
  -c:v libx264 -crf 20 -preset fast -an -r 30 /tmp/clip_features_3.mp4

# Hotbar resize clip
$FFMPEG -y -ss 3 -t 8 -i "Records/screen record of resizing hotbar view.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=black" \
  -c:v libx264 -crf 20 -preset fast -an -r 30 /tmp/clip_resize_hotbar.mp4

# Top bar resize clip
$FFMPEG -y -ss 3 -t 8 -i "Records/screen record of resizing top bar.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=black" \
  -c:v libx264 -crf 20 -preset fast -an -r 30 /tmp/clip_resize_topbar.mp4

echo "➡️ Step 2/5: Creating title and text cards..."

# Title card - 4 seconds
$FFMPEG -y -f lavfi -i "color=c=black:s=${W}x${H}:d=4:r=30" \
  -vf "drawtext=text='Pasty':fontsize=120:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2-40:fontfile=/System/Library/Fonts/SFCompact.ttf:alpha='if(lt(t,0.8),t/0.8,if(gt(t,3.2),(4-t)/0.8,1))',drawtext=text='Your clipboard, supercharged.':fontsize=36:fontcolor=0xBBBBBB:x=(w-text_w)/2:y=(h/2)+40:fontfile=/System/Library/Fonts/SFCompact.ttf:alpha='if(lt(t,1.2),(t-0.4)/0.8,if(gt(t,3.2),(4-t)/0.8,1))'" \
  -c:v libx264 -crf 18 -preset fast /tmp/card_title.mp4

# Feature text cards (2s each with fade)
for i in 1 2 3 4 5; do
  case $i in
    1) TXT="Native Swift"; SUB="Zero Electron. Zero Chromium.";;
    2) TXT="120Hz ProMotion"; SUB="Every scroll. Every animation.";;
    3) TXT="Code View"; SUB="30+ languages highlighted.";;
    4) TXT="Drag to Resize"; SUB="Both panels. Any edge.";;
    5) TXT="AES-256 Encrypted"; SUB="100% offline. 100% private.";;
  esac
  $FFMPEG -y -f lavfi -i "color=c=black:s=${W}x${H}:d=2.5:r=30" \
    -vf "drawtext=text='${TXT}':fontsize=72:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2-25:fontfile=/System/Library/Fonts/SFCompact.ttf:alpha='if(lt(t,0.5),t/0.5,if(gt(t,2),(2.5-t)/0.5,1))',drawtext=text='${SUB}':fontsize=28:fontcolor=0x999999:x=(w-text_w)/2:y=(h/2)+25:fontfile=/System/Library/Fonts/SFCompact.ttf:alpha='if(lt(t,0.7),(t-0.2)/0.5,if(gt(t,2),(2.5-t)/0.5,1))'" \
    -c:v libx264 -crf 18 -preset fast /tmp/card_feat_${i}.mp4
done

# Dual-menu highlight card - 3 seconds
$FFMPEG -y -f lavfi -i "color=c=black:s=${W}x${H}:d=3.5:r=30" \
  -vf "drawtext=text='Two Ways to Paste':fontsize=84:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2-80:fontfile=/System/Library/Fonts/SFCompact.ttf:alpha='if(lt(t,0.6),t/0.6,if(gt(t,2.8),(3.5-t)/0.7,1))',drawtext=text='⌥V  Hotbar — appears at your cursor, anywhere':fontsize=28:fontcolor=0xBBBBBB:x=(w-text_w)/2:y=(h/2)-10:fontfile=/System/Library/Fonts/SFCompact.ttf:alpha='if(lt(t,1),(t-0.4)/0.6,if(gt(t,2.8),(3.5-t)/0.7,1))',drawtext=text='Menu Bar — always one click away in your top bar':fontsize=28:fontcolor=0xBBBBBB:x=(w-text_w)/2:y=(h/2)+35:fontfile=/System/Library/Fonts/SFCompact.ttf:alpha='if(lt(t,1.3),(t-0.7)/0.6,if(gt(t,2.8),(3.5-t)/0.7,1))'" \
  -c:v libx264 -crf 18 -preset fast /tmp/card_dual_menu.mp4

# CTA end card - 4 seconds
$FFMPEG -y -f lavfi -i "color=c=black:s=${W}x${H}:d=4:r=30" \
  -vf "drawtext=text='Get Pasty':fontsize=96:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2-50:fontfile=/System/Library/Fonts/SFCompact.ttf:alpha='if(lt(t,0.8),t/0.8,1)',drawtext=text='pasty.dev':fontsize=40:fontcolor=0x95A7F1:x=(w-text_w)/2:y=(h/2)+30:fontfile=/System/Library/Fonts/SFCompact.ttf:alpha='if(lt(t,1.2),(t-0.4)/0.8,1)',drawtext=text='\$9.99 · Lifetime License':fontsize=24:fontcolor=0x888888:x=(w-text_w)/2:y=(h/2)+90:fontfile=/System/Library/Fonts/SFCompact.ttf:alpha='if(lt(t,1.5),(t-0.7)/0.8,1)'" \
  -c:v libx264 -crf 18 -preset fast /tmp/card_cta.mp4

echo "➡️ Step 3/5: Screenshot Ken Burns cards..."

for img in hotbar-codeview codeview-expanded topbar-overview; do
  $FFMPEG -y -loop 1 -i "website/assets/images/${img}.png" -t 3 \
    -vf "scale=2400:-1,zoompan=z='1+0.03*in/90':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=90:s=${W}x${H}:fps=30" \
    -c:v libx264 -crf 20 -preset fast -pix_fmt yuv420p /tmp/card_ss_${img}.mp4
done

echo "➡️ Step 4/5: Concatenating all segments..."

# Build the concat file
cat > /tmp/promo_concat.txt << 'EOF'
file '/tmp/card_title.mp4'
file '/tmp/card_feat_1.mp4'
file '/tmp/clip_features_1.mp4'
file '/tmp/card_feat_2.mp4'
file '/tmp/clip_features_2.mp4'
file '/tmp/card_feat_3.mp4'
file '/tmp/card_ss_codeview-expanded.mp4'
file '/tmp/clip_features_3.mp4'
file '/tmp/card_feat_4.mp4'
file '/tmp/clip_resize_hotbar.mp4'
file '/tmp/card_ss_hotbar-codeview.mp4'
file '/tmp/card_dual_menu.mp4'
file '/tmp/card_feat_5.mp4'
file '/tmp/clip_resize_topbar.mp4'
file '/tmp/card_ss_topbar-overview.mp4'
file '/tmp/card_cta.mp4'
EOF

$FFMPEG -y -f concat -safe 0 -i /tmp/promo_concat.txt \
  -c:v libx264 -crf 20 -preset fast -movflags +faststart -an \
  "$OUT"

echo "➡️ Step 5/5: Cleanup..."
rm -f /tmp/clip_*.mp4 /tmp/card_*.mp4 /tmp/promo_concat.txt

echo "✅ Promo video created: $OUT"
ls -lh "$OUT"
