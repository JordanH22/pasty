#!/bin/bash
set -e

cd /Users/jordanhill/Desktop/Pastry
FFMPEG="./ffmpeg -nostdin"
OUT="Pasty_Promo.mp4"
BASE_DIR="Records"
H_DIR="${BASE_DIR}/hotbar_clips"
T_DIR="${BASE_DIR}/topbar_clips"
W=1920
H=1080

echo "➡️ Step 1/4: Preparing Clips..."

# Clip 1: Speed (hotbar_clip_05)
$FFMPEG -y -i "$H_DIR/hotbar_clip_05.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=black" \
  -c:v libx264 -crf 20 -preset fast -an -r 60 /tmp/promo_clip_1.mp4

# Clip 2: Media & Apps (hotbar_clip_00 & 01)
$FFMPEG -y -i "$H_DIR/hotbar_clip_00.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=black" \
  -c:v libx264 -crf 20 -preset fast -an -r 60 /tmp/promo_clip_2.mp4

# Clip 3: Code View (hotbar_clip_02)
$FFMPEG -y -i "$H_DIR/hotbar_clip_02.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=black" \
  -c:v libx264 -crf 20 -preset fast -an -r 60 /tmp/promo_clip_3.mp4

# Clip 4: Drag to Resize (hotbar_clip_07)
$FFMPEG -y -i "$H_DIR/hotbar_clip_07.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=black" \
  -c:v libx264 -crf 20 -preset fast -an -r 60 /tmp/promo_clip_4.mp4

# Clip 5: Topbar action (topbar_clip_00 & 04)
# We will use topbar_clip_04 which shows edit and resize
$FFMPEG -y -i "$T_DIR/topbar_clip_04.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=black" \
  -c:v libx264 -crf 20 -preset fast -an -r 60 /tmp/promo_clip_5.mp4


echo "➡️ Step 2/4: Creating Title & Text Cards..."

# Title card - 4 seconds
$FFMPEG -y -f lavfi -i "color=c=black:s=${W}x${H}:d=4:r=60" \
  -vf "drawtext=text='Pasty':fontsize=120:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2-40:fontfile=/System/Library/Fonts/SFNS.ttf:alpha='if(lt(t,0.8),t/0.8,if(gt(t,3.2),(4-t)/0.8,1))',drawtext=text='Your clipboard, supercharged.':fontsize=36:fontcolor=0xBBBBBB:x=(w-text_w)/2:y=(h/2)+40:fontfile=/System/Library/Fonts/SFNS.ttf:alpha='if(lt(t,1.2),(t-0.4)/0.8,if(gt(t,3.2),(4-t)/0.8,1))'" \
  -c:v libx264 -crf 18 -preset fast /tmp/card_title.mp4

# Create text cards with crossfade alphas
create_feat_card() {
  local num=$1
  local header=$2
  local sub=$3
  $FFMPEG -y -f lavfi -i "color=c=black:s=${W}x${H}:d=2.5:r=60" \
    -vf "drawtext=text='${header}':fontsize=72:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2-25:fontfile=/System/Library/Fonts/SFNS.ttf:alpha='if(lt(t,0.5),t/0.5,if(gt(t,2),(2.5-t)/0.5,1))',drawtext=text='${sub}':fontsize=28:fontcolor=0x999999:x=(w-text_w)/2:y=(h/2)+25:fontfile=/System/Library/Fonts/SFNS.ttf:alpha='if(lt(t,0.7),(t-0.2)/0.5,if(gt(t,2),(2.5-t)/0.5,1))'" \
    -c:v libx264 -crf 18 -preset fast "/tmp/card_feat_${num}.mp4"
}

create_feat_card 1 "120Hz ProMotion" "Lightning fast, zero stutter."
create_feat_card 2 "Native Swift" "Images, files, and apps supported natively."
create_feat_card 3 "Code View Highlight" "30+ languages beautifully formatted."
create_feat_card 4 "Fluid Resizing" "Mold your clipboard to your workflow."
create_feat_card 5 "Two Ways to Paste" "Hotbar anywhere, or Menu Bar always."

# Callout for Dual Menu
$FFMPEG -y -f lavfi -i "color=c=black:s=${W}x${H}:d=3.5:r=60" \
  -vf "drawtext=text='Top Menu Access':fontsize=84:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2-80:fontfile=/System/Library/Fonts/SFNS.ttf:alpha='if(lt(t,0.6),t/0.6,if(gt(t,2.8),(3.5-t)/0.7,1))',drawtext=text='Always one click away, seamlessly syncing.':fontsize=28:fontcolor=0xBBBBBB:x=(w-text_w)/2:y=(h/2)-10:fontfile=/System/Library/Fonts/SFNS.ttf:alpha='if(lt(t,1),(t-0.4)/0.6,if(gt(t,2.8),(3.5-t)/0.7,1))'" \
  -c:v libx264 -crf 18 -preset fast /tmp/card_feat_menu.mp4

# CTA card
$FFMPEG -y -f lavfi -i "color=c=black:s=${W}x${H}:d=4:r=60" \
  -vf "drawtext=text='Get Pasty':fontsize=96:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2-50:fontfile=/System/Library/Fonts/SFNS.ttf:alpha='if(lt(t,0.8),t/0.8,1)',drawtext=text='pasty.dev':fontsize=40:fontcolor=0x95A7F1:x=(w-text_w)/2:y=(h/2)+30:fontfile=/System/Library/Fonts/SFNS.ttf:alpha='if(lt(t,1.2),(t-0.4)/0.8,1)',drawtext=text='\$9.99 · Lifetime License':fontsize=24:fontcolor=0x888888:x=(w-text_w)/2:y=(h/2)+90:fontfile=/System/Library/Fonts/SFNS.ttf:alpha='if(lt(t,1.5),(t-0.7)/0.8,1)'" \
  -c:v libx264 -crf 18 -preset fast /tmp/card_cta.mp4


echo "➡️ Step 3/4: Consolidating Promo Video..."

cat > /tmp/promo_concat.txt << 'EOF'
file '/tmp/card_title.mp4'
file '/tmp/card_feat_1.mp4'
file '/tmp/promo_clip_1.mp4'
file '/tmp/card_feat_2.mp4'
file '/tmp/promo_clip_2.mp4'
file '/tmp/card_feat_3.mp4'
file '/tmp/promo_clip_3.mp4'
file '/tmp/card_feat_4.mp4'
file '/tmp/promo_clip_4.mp4'
file '/tmp/card_feat_menu.mp4'
file '/tmp/card_feat_5.mp4'
file '/tmp/promo_clip_5.mp4'
file '/tmp/card_cta.mp4'
EOF

$FFMPEG -y -f concat -safe 0 -i /tmp/promo_concat.txt \
  -c:v libx264 -crf 18 -preset fast -movflags +faststart -an \
  "$OUT"

echo "➡️ Step 4/4: Generating Website Master Videos..."
# Combine Hotbar Clips
cat > /tmp/hotbar_web_concat.txt << 'EOF'
file '/Users/jordanhill/Desktop/Pastry/Records/hotbar_clips/hotbar_clip_05.mov'
file '/Users/jordanhill/Desktop/Pastry/Records/hotbar_clips/hotbar_clip_00.mov'
file '/Users/jordanhill/Desktop/Pastry/Records/hotbar_clips/hotbar_clip_01.mov'
file '/Users/jordanhill/Desktop/Pastry/Records/hotbar_clips/hotbar_clip_02.mov'
file '/Users/jordanhill/Desktop/Pastry/Records/hotbar_clips/hotbar_clip_07.mov'
file '/Users/jordanhill/Desktop/Pastry/Records/hotbar_clips/hotbar_clip_08.mov'
EOF

$FFMPEG -y -f concat -safe 0 -i /tmp/hotbar_web_concat.txt \
  -c:v libx264 -crf 23 -preset fast -pix_fmt yuv420p -an \
  "website/assets/videos/hotbar-demo.mp4"

# Combine Topbar Clips
cat > /tmp/topbar_web_concat.txt << 'EOF'
file '/Users/jordanhill/Desktop/Pastry/Records/topbar_clips/topbar_clip_00.mov'
file '/Users/jordanhill/Desktop/Pastry/Records/topbar_clips/topbar_clip_02.mov'
file '/Users/jordanhill/Desktop/Pastry/Records/topbar_clips/topbar_clip_03.mov'
file '/Users/jordanhill/Desktop/Pastry/Records/topbar_clips/topbar_clip_04.mov'
file '/Users/jordanhill/Desktop/Pastry/Records/topbar_clips/topbar_clip_05.mov'
EOF

$FFMPEG -y -f concat -safe 0 -i /tmp/topbar_web_concat.txt \
  -c:v libx264 -crf 23 -preset fast -pix_fmt yuv420p -an \
  "website/assets/videos/topbar-demo.mp4"

echo "✅ All Media Processed!"
