#!/bin/bash
set -e

cd /Users/jordanhill/Desktop/Pastry
FFMPEG="./ffmpeg -nostdin"
OUT="Pasty_Promo_4K.mp4"
BASE_DIR="Records"
H_DIR="${BASE_DIR}/hotbar_clips"
T_DIR="${BASE_DIR}/topbar_clips"
# UHD 4K Resolution
W=3840
H=2160
LOGO="website/assets/images/logo_round.png"

echo "➡️ Step 1/4: Preparing 4K High-Def Clips..."

# Clip 1: Speed
$FFMPEG -y -i "$H_DIR/hotbar_clip_05.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=0x0a0a0c" \
  -c:v libx264 -crf 16 -preset fast -an -r 60 /tmp/promo_4k_clip_1.mp4 2>/dev/null

# Clip 2: Media & Apps
$FFMPEG -y -i "$H_DIR/hotbar_clip_00.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=0x0a0a0c" \
  -c:v libx264 -crf 16 -preset fast -an -r 60 /tmp/promo_4k_clip_2.mp4 2>/dev/null

# Clip 3: Code View
$FFMPEG -y -i "$H_DIR/hotbar_clip_02.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=0x0a0a0c" \
  -c:v libx264 -crf 16 -preset fast -an -r 60 /tmp/promo_4k_clip_3.mp4 2>/dev/null

# Clip 4: Drag to Resize
$FFMPEG -y -i "$H_DIR/hotbar_clip_07.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=0x0a0a0c" \
  -c:v libx264 -crf 16 -preset fast -an -r 60 /tmp/promo_4k_clip_4.mp4 2>/dev/null

# Clip 5: Topbar
$FFMPEG -y -i "$T_DIR/topbar_clip_04.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=0x0a0a0c" \
  -c:v libx264 -crf 16 -preset fast -an -r 60 /tmp/promo_4k_clip_5.mp4 2>/dev/null


echo "➡️ Step 2/4: Creating Cinematic 4K Apple-Style Title Cards..."

# Title card - 4 seconds with Logo
$FFMPEG -y -i "$LOGO" -f lavfi -i "color=c=0x0a0a0c:s=${W}x${H}:d=4:r=60" \
  -filter_complex "[0:v]scale=-1:360[logo]; \
  [1:v][logo]overlay=(W-w)/2:(H-h)/2-360:enable='between(t,0,4)'[with_logo]; \
  [with_logo]drawtext=text='Pasty':fontsize=220:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2+120-(60*t/2):fontfile=/System/Library/Fonts/SFNS-Bold.ttf:alpha='if(lt(t,0.8),t/0.8,if(gt(t,3.2),(4-t)/0.8,1))', \
  drawtext=text='Your clipboard, supercharged.':fontsize=84:fontcolor=0x95A7F1:x=(w-text_w)/2:y=(h/2)+260-(40*t/2):fontfile=/System/Library/Fonts/SFNS.ttf:alpha='if(lt(t,1.2),(t-0.4)/0.8,if(gt(t,3.2),(4-t)/0.8,1))'" \
  -c:v libx264 -crf 16 -preset fast /tmp/card_4k_title.mp4 2>/dev/null

# Create feature cards with crossfade alphas + subtle floating text
create_feat_card() {
  local num=$1
  local header=$2
  local sub=$3
  local color=$4
  $FFMPEG -y -f lavfi -i "color=c=0x0a0a0c:s=${W}x${H}:d=2.5:r=60" \
    -vf "drawtext=text='${header}':fontsize=160:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2-60-(40*t/1.5):fontfile=/System/Library/Fonts/SFNS-Bold.ttf:alpha='if(lt(t,0.5),t/0.5,if(gt(t,2),(2.5-t)/0.5,1))', \
         drawtext=text='${sub}':fontsize=64:fontcolor=${color}:x=(w-text_w)/2:y=(h/2)+80-(40*t/1.5):fontfile=/System/Library/Fonts/SFNS.ttf:alpha='if(lt(t,0.7),(t-0.2)/0.5,if(gt(t,2),(2.5-t)/0.5,1))'" \
    -c:v libx264 -crf 16 -preset fast "/tmp/card_4k_feat_${num}.mp4" 2>/dev/null
}

create_feat_card 1 "120Hz ProMotion" "Lightning fast, zero stutter." "0x60A5FA"
create_feat_card 2 "Native Architecture" "Images, files, and apps supported flawlessly." "0xA855F7"
create_feat_card 3 "Smart Code View" "Syntax highlighting for 30+ languages." "0xFACC15"
create_feat_card 4 "Fluid Workflow" "Dynamic resizing to fit your screen." "0x34D399"

# Special Callout for Dual Menu
$FFMPEG -y -f lavfi -i "color=c=0x0a0a0c:s=${W}x${H}:d=3.5:r=60" \
  -vf "drawtext=text='Always Accessible':fontsize=180:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2-100-(40*t/2):fontfile=/System/Library/Fonts/SFNS-Bold.ttf:alpha='if(lt(t,0.6),t/0.6,if(gt(t,2.8),(3.5-t)/0.7,1))', \
       drawtext=text='Invoke the floating Hotbar, or click the Menu icon.':fontsize=64:fontcolor=0xA1A1AA:x=(w-text_w)/2:y=(h/2)+80-(20*t/2):fontfile=/System/Library/Fonts/SFNS.ttf:alpha='if(lt(t,1),(t-0.4)/0.6,if(gt(t,2.8),(3.5-t)/0.7,1))'" \
  -c:v libx264 -crf 16 -preset fast /tmp/card_4k_feat_menu.mp4 2>/dev/null

# CTA / Ending card with Logo
$FFMPEG -y -i "$LOGO" -f lavfi -i "color=c=0x0a0a0c:s=${W}x${H}:d=5:r=60" \
  -filter_complex "[0:v]scale=-1:360[logo]; \
  [1:v][logo]overlay=(W-w)/2:(H-h)/2-420:enable='between(t,0,5)'[with_logo]; \
  [with_logo]drawtext=text='Get Pasty Today':fontsize=180:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2+40-(30*t/2):fontfile=/System/Library/Fonts/SFNS-Bold.ttf:alpha='if(lt(t,0.8),t/0.8,if(gt(t,4.5),(5-t)/0.5,1))', \
  drawtext=text='pasty.dev':fontsize=96:fontcolor=0x4ADE80:x=(w-text_w)/2:y=(h/2)+220-(30*t/2):fontfile=/System/Library/Fonts/SFNS.ttf:alpha='if(lt(t,1.2),(t-0.4)/0.8,if(gt(t,4.5),(5-t)/0.5,1))', \
  drawtext=text='Available purely for macOS.':fontsize=56:fontcolor=0x71717A:x=(w-text_w)/2:y=(h/2)+360-(20*t/2):fontfile=/System/Library/Fonts/SFNS.ttf:alpha='if(lt(t,1.6),(t-0.8)/0.8,if(gt(t,4.5),(5-t)/0.5,1))'" \
  -c:v libx264 -crf 16 -preset fast /tmp/card_4k_cta.mp4 2>/dev/null


echo "➡️ Step 3/4: Rendering the 4K Master File..."

cat > /tmp/promo_4k_concat.txt << 'EOF'
file '/tmp/card_4k_title.mp4'
file '/tmp/card_4k_feat_1.mp4'
file '/tmp/promo_4k_clip_1.mp4'
file '/tmp/card_4k_feat_2.mp4'
file '/tmp/promo_4k_clip_2.mp4'
file '/tmp/card_4k_feat_3.mp4'
file '/tmp/promo_4k_clip_3.mp4'
file '/tmp/card_4k_feat_4.mp4'
file '/tmp/promo_4k_clip_4.mp4'
file '/tmp/card_4k_feat_menu.mp4'
file '/tmp/promo_4k_clip_5.mp4'
file '/tmp/card_4k_cta.mp4'
EOF

$FFMPEG -y -f concat -safe 0 -i /tmp/promo_4k_concat.txt \
  -c:v libx264 -crf 14 -preset medium -movflags +faststart -an \
  "$OUT"

echo "✅ Beautiful, Cinematic 4K Promo Master Rendered at $OUT!"
