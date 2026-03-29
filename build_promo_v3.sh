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
LOGO="website/assets/images/logo.png"

echo "➡️ Step 1/4: Preparing Clips (Maintaining Crispness)..."

# Clip 1: Speed
$FFMPEG -y -i "$H_DIR/hotbar_clip_05.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=0x0a0a0c" \
  -c:v libx264 -crf 18 -preset fast -an -r 60 /tmp/promo_clip_1.mp4 2>/dev/null

# Clip 2: Media & Apps
$FFMPEG -y -i "$H_DIR/hotbar_clip_00.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=0x0a0a0c" \
  -c:v libx264 -crf 18 -preset fast -an -r 60 /tmp/promo_clip_2.mp4 2>/dev/null

# Clip 3: Code View
$FFMPEG -y -i "$H_DIR/hotbar_clip_02.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=0x0a0a0c" \
  -c:v libx264 -crf 18 -preset fast -an -r 60 /tmp/promo_clip_3.mp4 2>/dev/null

# Clip 4: Drag to Resize
$FFMPEG -y -i "$H_DIR/hotbar_clip_07.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=0x0a0a0c" \
  -c:v libx264 -crf 18 -preset fast -an -r 60 /tmp/promo_clip_4.mp4 2>/dev/null

# Clip 5: Topbar
$FFMPEG -y -i "$T_DIR/topbar_clip_04.mov" \
  -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=0x0a0a0c" \
  -c:v libx264 -crf 18 -preset fast -an -r 60 /tmp/promo_clip_5.mp4 2>/dev/null


echo "➡️ Step 2/4: Creating Cinematic Apple-Style Title Cards..."

# We use 0x0a0a0c (very deep space grey) for true Apple vibe, not pure black.
# We also make the text elegantly "float" upwards as it fades in (a classic Apple motion design).

# Title card - 4 seconds with Logo
$FFMPEG -y -i "$LOGO" -f lavfi -i "color=c=0x0a0a0c:s=${W}x${H}:d=4:r=60" \
  -filter_complex "[0:v]scale=-1:180[logo]; \
  [1:v][logo]overlay=(W-w)/2:(H-h)/2-120:enable='between(t,0,4)'[with_logo]; \
  [with_logo]drawtext=text='Pasty':fontsize=110:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2+40-(30*t/2):fontfile=/System/Library/Fonts/SFNS-Bold.ttf:alpha='if(lt(t,0.8),t/0.8,if(gt(t,3.2),(4-t)/0.8,1))', \
  drawtext=text='Your clipboard, supercharged.':fontsize=42:fontcolor=0x95A7F1:x=(w-text_w)/2:y=(h/2)+110-(20*t/2):fontfile=/System/Library/Fonts/SFNS.ttf:alpha='if(lt(t,1.2),(t-0.4)/0.8,if(gt(t,3.2),(4-t)/0.8,1))'" \
  -c:v libx264 -crf 18 -preset fast /tmp/card_title.mp4 2>/dev/null

# Create feature cards with crossfade alphas + subtle floating text
create_feat_card() {
  local num=$1
  local header=$2
  local sub=$3
  local color=$4
  $FFMPEG -y -f lavfi -i "color=c=0x0a0a0c:s=${W}x${H}:d=2.5:r=60" \
    -vf "drawtext=text='${header}':fontsize=80:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2-30-(20*t/1.5):fontfile=/System/Library/Fonts/SFNS-Bold.ttf:alpha='if(lt(t,0.5),t/0.5,if(gt(t,2),(2.5-t)/0.5,1))', \
         drawtext=text='${sub}':fontsize=32:fontcolor=${color}:x=(w-text_w)/2:y=(h/2)+40-(20*t/1.5):fontfile=/System/Library/Fonts/SFNS.ttf:alpha='if(lt(t,0.7),(t-0.2)/0.5,if(gt(t,2),(2.5-t)/0.5,1))'" \
    -c:v libx264 -crf 18 -preset fast "/tmp/card_feat_${num}.mp4" 2>/dev/null
}

# The website uses nice neon accent colors! I'll apply those distinct colors to subtitle text to make it extremely modern.
create_feat_card 1 "120Hz ProMotion" "Lightning fast, zero stutter." "0x60A5FA"       # Blueish
create_feat_card 2 "Native Architecture" "Images, files, and apps supported flawlessly." "0xA855F7"    # Purpleish
create_feat_card 3 "Smart Code View" "Syntax highlighting for 30+ languages." "0xFACC15"           # Yellowish
create_feat_card 4 "Fluid Workflow" "Dynamic resizing to fit your screen." "0x34D399"              # Greenish

# Special Callout for Dual Menu
$FFMPEG -y -f lavfi -i "color=c=0x0a0a0c:s=${W}x${H}:d=3.5:r=60" \
  -vf "drawtext=text='Always Accessible':fontsize=90:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2-50-(20*t/2):fontfile=/System/Library/Fonts/SFNS-Bold.ttf:alpha='if(lt(t,0.6),t/0.6,if(gt(t,2.8),(3.5-t)/0.7,1))', \
       drawtext=text='Invoke the floating Hotbar, or click the Menu icon.':fontsize=32:fontcolor=0xA1A1AA:x=(w-text_w)/2:y=(h/2)+40-(10*t/2):fontfile=/System/Library/Fonts/SFNS.ttf:alpha='if(lt(t,1),(t-0.4)/0.6,if(gt(t,2.8),(3.5-t)/0.7,1))'" \
  -c:v libx264 -crf 18 -preset fast /tmp/card_feat_menu.mp4 2>/dev/null

# CTA / Ending card with Logo
$FFMPEG -y -i "$LOGO" -f lavfi -i "color=c=0x0a0a0c:s=${W}x${H}:d=5:r=60" \
  -filter_complex "[0:v]scale=-1:180[logo]; \
  [1:v][logo]overlay=(W-w)/2:(H-h)/2-160:enable='between(t,0,5)'[with_logo]; \
  [with_logo]drawtext=text='Get Pasty Today':fontsize=90:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2+20-(15*t/2):fontfile=/System/Library/Fonts/SFNS-Bold.ttf:alpha='if(lt(t,0.8),t/0.8,if(gt(t,4.5),(5-t)/0.5,1))', \
  drawtext=text='pasty.dev':fontsize=48:fontcolor=0x4ADE80:x=(w-text_w)/2:y=(h/2)+110-(15*t/2):fontfile=/System/Library/Fonts/SFNS.ttf:alpha='if(lt(t,1.2),(t-0.4)/0.8,if(gt(t,4.5),(5-t)/0.5,1))', \
  drawtext=text='Available purely for macOS.':fontsize=28:fontcolor=0x71717A:x=(w-text_w)/2:y=(h/2)+180-(10*t/2):fontfile=/System/Library/Fonts/SFNS.ttf:alpha='if(lt(t,1.6),(t-0.8)/0.8,if(gt(t,4.5),(5-t)/0.5,1))'" \
  -c:v libx264 -crf 18 -preset fast /tmp/card_cta.mp4 2>/dev/null


echo "➡️ Step 3/4: Rendering the Master File..."

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
file '/tmp/promo_clip_5.mp4'
file '/tmp/card_cta.mp4'
EOF

$FFMPEG -y -f concat -safe 0 -i /tmp/promo_concat.txt \
  -c:v libx264 -crf 16 -preset fast -movflags +faststart -an \
  "$OUT"

echo "✅ Beautiful, Cinematic Promo Master Rendered at $OUT!"
