#!/usr/bin/env fish
# fastuma — fastuma.fish
# Selects character/outfit and runs fastfetch with that image.
# Lives at ~/.local/share/fastuma/fastuma.fish

# ── paths ─────────────────────────────────────────────────────
set APP_DIR (dirname (realpath (status filename)))
set CONF_FILE "$APP_DIR/fastuma.conf"

if test (count $argv) -ge 2 -a "$argv[1]" = "--conf"
    set CONF_FILE $argv[2]
end

# ── load config ───────────────────────────────────────────────
if not test -f $CONF_FILE
    echo "[ERROR] Config not found: $CONF_FILE" >&2; exit 1
end

# defaults
set RESOURCE                 "outfit"
set RANDOM_CHARA             "true"
set RANDOM_OUTFIT            "true"
set FIXED_CHARA_ID           "1015"
set FIXED_OUTFIT_INDEX       "0"
set SEPARATOR                " - "
set NAME_CASE                "upper"
set RESOURCE_NAME_CASE       "upper"
set RESOURCE_NAME_DECORATION "true"
set COLOR_DYNAMIC            "false"
set NAME_PREFIX              ""
set NAME_SUFFIX              ""
set RESOURCE_NAME_PREFIX     ""
set RESOURCE_NAME_SUFFIX     ""
set NAME_COLOR               ""
set RESOURCE_NAME_COLOR      ""
set FASTFETCH_CONFIG         "$HOME/.config/fastfetch/config.jsonc"
set IMAGE_PROTOCOL           "kitty"

# parse config file — bulletproof for Fish
cat $CONF_FILE | while read -l line
    set line (string trim $line)
    if string match -qr '^#' "$line"; or test -z "$line"
        continue
    end
    
    set parts (string split -m1 '=' "$line")
    set key (string trim "$parts[1]")
    
    # Safe trim: strip spaces and then remove quotes step by step
    set val (string trim "$parts[2]")
    set val (string trim -c '"' "$val")
    set val (string trim -c "'" "$val")
    
    switch "$key"
        case RESOURCE;                  set RESOURCE "$val"
        case RANDOM_CHARA;              set RANDOM_CHARA "$val"
        case RANDOM_OUTFIT;             set RANDOM_OUTFIT "$val"
        case FIXED_CHARA_ID;            set FIXED_CHARA_ID "$val"
        case FIXED_OUTFIT_INDEX;        set FIXED_OUTFIT_INDEX "$val"
        case SEPARATOR;                 set SEPARATOR "$val"
        case NAME_CASE;                 set NAME_CASE "$val"
        case RESOURCE_NAME_CASE;        set RESOURCE_NAME_CASE "$val"
        case RESOURCE_NAME_DECORATION;  set RESOURCE_NAME_DECORATION "$val"
        case COLOR_DYNAMIC;             set COLOR_DYNAMIC "$val"
        case NAME_PREFIX;               set NAME_PREFIX "$val"
        case NAME_SUFFIX;               set NAME_SUFFIX "$val"
        case RESOURCE_NAME_PREFIX;      set RESOURCE_NAME_PREFIX "$val"
        case RESOURCE_NAME_SUFFIX;      set RESOURCE_NAME_SUFFIX "$val"
        case NAME_COLOR;                set NAME_COLOR "$val"
        case RESOURCE_NAME_COLOR;       set RESOURCE_NAME_COLOR "$val"
        case FASTFETCH_CONFIG;          set FASTFETCH_CONFIG "$val"
        case IMAGE_PROTOCOL;            set IMAGE_PROTOCOL "$val"
    end
end

# ── resolve paths ─────────────────────────────────────────────
set JSON      "$APP_DIR/uma_grouped.json"
set IMG_DIR   "$APP_DIR/resource/$RESOURCE"
set FF_CONFIG (string replace '~' $HOME $FASTFETCH_CONFIG)
set TMP       "/tmp/fastuma-$fish_pid.jsonc"

# ── validate ──────────────────────────────────────────────────
if not test -f $JSON
    echo "[ERROR] uma_grouped.json not found. Run: fish install.fish" >&2; exit 1
end
if not test -f $FF_CONFIG
    echo "[ERROR] Fastfetch config not found: $FF_CONFIG" >&2; exit 1
end
if not test -d $IMG_DIR
    echo "[ERROR] Image dir not found: $IMG_DIR" >&2; exit 1
end

# ── pick character ────────────────────────────────────────────
if test "$RANDOM_CHARA" = "true"
    set CHARA_ID (jq -r 'keys[]' $JSON | shuf -n 1)
else
    if test -z "$FIXED_CHARA_ID"
        echo "[ERROR] RANDOM_CHARA=false but FIXED_CHARA_ID is empty." >&2; exit 1
    end
    set CHARA_ID $FIXED_CHARA_ID
end

set NAME (jq -r --arg cid "$CHARA_ID" '.[$cid].name // empty' $JSON)
if test -z "$NAME"
    echo "[ERROR] Character '$CHARA_ID' not found in JSON." >&2; exit 1
end

# ── pick outfit ───────────────────────────────────────────────
if test "$RANDOM_OUTFIT" = "true"
    # Added `tojson` to prevent jq from collapsing when encoding objects to base64
    set OUTFIT_B64 (jq -r --arg cid "$CHARA_ID" '.[$cid].outfits[] | tojson | @base64' $JSON | shuf -n 1)
else
    if test -z "$FIXED_OUTFIT_INDEX"
        set FIXED_OUTFIT_INDEX 0
    end
    
    set OUTFIT_B64 (jq -r --arg cid "$CHARA_ID" --argjson idx "$FIXED_OUTFIT_INDEX" '.[$cid].outfits[$idx] | tojson | @base64' $JSON)
    
    # Error handling if index is invalid (jq returns null in base64 = bnVsbA==)
    if test -z "$OUTFIT_B64"; or test "$OUTFIT_B64" = "bnVsbA=="
        echo "[ERROR] Outfit index '$FIXED_OUTFIT_INDEX' not found for character '$CHARA_ID'." >&2; exit 1
    end
end

set OUTFIT_TITLE (echo "$OUTFIT_B64" | base64 --decode | jq -r '.title')
set OUTFIT_IMAGE (echo "$OUTFIT_B64" | base64 --decode | jq -r '.image')
set IMAGE_PATH   "$IMG_DIR/$OUTFIT_IMAGE"

if not test -f "$IMAGE_PATH"
    echo "[ERROR] Image not found: $IMAGE_PATH. Run: fish install.fish" >&2; exit 1
end

# ── build title ───────────────────────────────────────────────

if test "$COLOR_DYNAMIC" = "true"
    # Scans the image for the most prominent colors, ignores transparent ones (#...00)
    # and sorts them by luminance (brightness)
    set -l extracted (magick "$IMAGE_PATH" -scale 50x50 -colors 5 -unique-colors txt: | awk -F'[(), ]+' 'NR>1 {if($6~/^#/){hex=$6;a=255}else{hex=$7;a=$6}; if(a>200){print 0.299*$3+0.587*$4+0.114*$5, substr(hex,1,7)}}' | sort -n | awk '{print $2}')
    
    # If at least 2 colors were detected, assign them
    if test (count $extracted) -ge 2
        # The lightest color for the name
        set NAME_COLOR $extracted[-1]
        
        # To avoid colors that are too dark (e.g. shadows/outlines), take the 2nd lightest
        if test (count $extracted) -ge 3
            set RESOURCE_NAME_COLOR $extracted[-2]
        else
            set RESOURCE_NAME_COLOR $extracted[1]
        end
    end
end

if test "$RESOURCE_NAME_DECORATION" = "false"
    set OUTFIT_TITLE (string replace -a '[' '' "$OUTFIT_TITLE" | string replace -a ']' '')
end

function apply_case
    set -l text $argv[1]
    set -l case_type $argv[2]
    switch "$case_type"
        case "upper"
            echo "$text" | string upper
        case "lower"
            echo "$text" | string lower
        case "capitalize"
            echo "$text" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1'
        case "*"
            echo "$text"
    end
end

set FINAL_NAME "$NAME_PREFIX"(apply_case "$NAME" "$NAME_CASE")"$NAME_SUFFIX"
set FINAL_OUTFIT "$RESOURCE_NAME_PREFIX"(apply_case "$OUTFIT_TITLE" "$RESOURCE_NAME_CASE")"$RESOURCE_NAME_SUFFIX"

set -l title_name "$FINAL_NAME"
if test -n "$NAME_COLOR"
    set -l c "$NAME_COLOR"
    string match -q "{#*" "$c"; or set c "{#$c}"
    set title_name "$c$FINAL_NAME{#0}"
end

set -l title_outfit "$FINAL_OUTFIT"
if test -n "$RESOURCE_NAME_COLOR"
    set -l c "$RESOURCE_NAME_COLOR"
    string match -q "{#*" "$c"; or set c "{#$c}"
    set title_outfit "$c$FINAL_OUTFIT{#0}"
end

set TITLE "$title_name$SEPARATOR$title_outfit"

# ── patch fastfetch config ────────────────────────────────────
cp $FF_CONFIG $TMP

# Optimized sed replacement that avoids Fish line break bugs
sed -i '/\/\/ fastuma-title/d' $TMP
sed -i "s|^\([[:space:]]*\"modules\"[[:space:]]*:[[:space:]]*\[\)|\1\n        { \"type\": \"custom\", \"format\": \"$TITLE\" }, // fastuma-title|" $TMP

# ── run ───────────────────────────────────────────────────────
fastfetch --config $TMP --logo "$IMAGE_PATH" --logo-type "$IMAGE_PROTOCOL"
rm -f $TMP