#!/usr/bin/env fish
# fastuma — install.fish
# Installs the app and downloads resources from the API.
# Usage: fish install.fish

set APP_DIR (dirname (realpath (status filename)))
set BIN_DIR "$HOME/.local/bin"

# ── banner ────────────────────────────────────────────────────
echo ""
echo "  ███████╗ █████╗ ███████╗████████╗██╗   ██╗███╗   ███╗ █████╗ "
echo "  ██╔════╝██╔══██╗██╔════╝╚══██╔══╝██║   ██║████╗ ████║██╔══██╗"
echo "  █████╗  ███████║███████╗   ██║   ██║   ██║██╔████╔██║███████║"
echo "  ██╔══╝  ██╔══██║╚════██║   ██║   ██║   ██║██║╚██╔╝██║██╔══██║"
echo "  ██║     ██║  ██║███████║   ██║   ╚██████╔╝██║ ╚═╝ ██║██║  ██║"
echo "  ╚═╝     ╚═╝  ╚═╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝"
echo "  ──────────────────────────────────────────────────────────────"
echo "  Asset Installer  •  v1.0"
echo "  ──────────────────────────────────────────────────────────────"
echo ""

# ── BLOCK 1: create directories ───────────────────────────────
echo "[FASTUMA] Creating directories..."
mkdir -p "$APP_DIR/resource/outfit"
mkdir -p "$APP_DIR/resource/card"
mkdir -p "$APP_DIR/resource/icon"
mkdir -p "$BIN_DIR"

# ── BLOCK 2: permissions ──────────────────────────────────────
echo "[FASTUMA] Setting permissions..."
chmod +x "$APP_DIR/fastuma.fish"

# ── BLOCK 3: symlink ──────────────────────────────────────────
ln -sf "$APP_DIR/fastuma.fish" "$BIN_DIR/fastuma"
echo "[FASTUMA] Symlink → $BIN_DIR/fastuma"

# ── BLOCK 4: PATH check ───────────────────────────────────────
if not contains "$BIN_DIR" $PATH
    echo ""
    echo "[FASTUMA] WARNING: $BIN_DIR is not in your PATH."
    echo "          fish     : fish_add_path ~/.local/bin"
end

# ── BLOCK 5: fetch API ────────────────────────────────────────
echo ""
echo "[FASTUMA] Fetching outfit list from API..."

set API_URL "https://umapyoi.net/api/v1/outfit"
set OUTPUT_JSON "$APP_DIR/uma_grouped.json"
set IMG_DIR "$APP_DIR/resource/outfit"

set DATA (curl -s "$API_URL")
if test -z "$DATA"
    echo "[ERROR] Could not reach API. Check your connection." >&2
    exit 1
end

set TOTAL (echo "$DATA" | jq '[.[]] | length')
echo "[FASTUMA] Found $TOTAL entries. Downloading assets..."
echo ""

# ── BLOCK 6: download assets ──────────────────────────────────
set COUNT 0
set SKIPPED 0
set FAILED 0

if not test -f "$OUTPUT_JSON"
    echo "{}" > "$OUTPUT_JSON"
end

echo "$DATA" | jq -c '.[]' | while read -l item
    set chara_id (echo "$item" | jq -r '.chara_game_id')
    set outfit_id (echo "$item" | jq -r '.id')
    set gametora (echo "$item"  | jq -r '.gametora')
    set title (echo "$item"     | jq -r '.title')
    
    set name (string split '-' $gametora | tail -n +2 | string join ' ')

    set filename "$chara_id-$outfit_id.png"
    set filepath "$IMG_DIR/$filename"
    set img_url "https://gametora.com/images/umamusume/characters/chara_stand_"$chara_id"_"$outfit_id".png"

    if not test -f "$filepath"
        curl -s -L -o "$filepath" "$img_url"
        
        # Bug fix: changed to -rqi to act like a grep searching for substring
        if not test -s "$filepath"; or not file "$filepath" | string match -rqi "png"
            echo "[WARNING] Image not found: $filename"
            rm -f "$filepath"
            set FAILED (math $FAILED + 1)
        end
    else
        set SKIPPED (math $SKIPPED + 1)
    end

    set COUNT (math $COUNT + 1)

    jq \
      --arg  cid   "$chara_id"  \
      --arg  name  "$name"      \
      --arg  img   "$filename"  \
      --arg  title "$title"     \
      --argjson oid "$outfit_id" \
    '
    .[$cid] = (.[$cid] // {name: $name, outfits: []})
    | .[$cid].name = $name
    | .[$cid].outfits |= (
        map(select(.id != $oid)) + [{id: $oid, title: $title, image: $img}]
      )
    ' "$OUTPUT_JSON" > "$OUTPUT_JSON.tmp"

    mv "$OUTPUT_JSON.tmp" "$OUTPUT_JSON"
end

# ── BLOCK 7: done ─────────────────────────────────────────────
set DOWNLOADED (math $COUNT - $SKIPPED - $FAILED)
echo ""
echo "[FASTUMA] ──────────────────────────────────────"
echo "[FASTUMA] Done! $COUNT entries processed."
echo "[FASTUMA] Downloaded : $DOWNLOADED"
echo "[FASTUMA] Skipped    : $SKIPPED (already existed)"
echo "[FASTUMA] Failed     : $FAILED"
echo "[FASTUMA] JSON       → $OUTPUT_JSON"
echo "[FASTUMA] Images     → $IMG_DIR"
echo "[FASTUMA] ──────────────────────────────────────"
echo ""
echo "  Run: fastuma"
echo ""2