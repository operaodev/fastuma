#!/usr/bin/env bash
# fastuma — install.sh
# Instala la app y descarga los recursos de la API.
# Usage: bash install.sh

set -euo pipefail

APP_DIR="$HOME/.local/share/fastuma"
BIN_DIR="$HOME/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# ── BLOCK 1: crear directorios ────────────────────────────────
echo "[FASTUMA] Creating directories..."
mkdir -p "$APP_DIR/resource/outfit"
mkdir -p "$APP_DIR/resource/card"
mkdir -p "$APP_DIR/resource/icon"
mkdir -p "$BIN_DIR"

# ── BLOCK 2: copiar archivos ──────────────────────────────────
echo "[FASTUMA] Installing files..."
cp "$SCRIPT_DIR/fastuma.sh" "$APP_DIR/fastuma.sh"
chmod +x "$APP_DIR/fastuma.sh"

if [[ ! -f "$APP_DIR/fastuma.conf" ]]; then
    cp "$SCRIPT_DIR/fastuma.conf" "$APP_DIR/fastuma.conf"
    echo "[FASTUMA] Config installed → $APP_DIR/fastuma.conf"
else
    echo "[FASTUMA] Config already exists — not overwritten."
fi

# ── BLOCK 3: symlink ──────────────────────────────────────────
ln -sf "$APP_DIR/fastuma.sh" "$BIN_DIR/fastuma"
echo "[FASTUMA] Symlink → $BIN_DIR/fastuma"

# ── BLOCK 4: PATH check ───────────────────────────────────────
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo ""
    echo "[FASTUMA] WARNING: $BIN_DIR is not in your PATH."
    echo "          bash/zsh : export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo "          fish     : fish_add_path ~/.local/bin"
fi

# ── BLOCK 5: fetch API ────────────────────────────────────────
echo ""
echo "[FASTUMA] Fetching outfit list from API..."

API_URL="https://umapyoi.net/api/v1/outfit"
OUTPUT_JSON="$APP_DIR/uma_grouped.json"
IMG_DIR="$APP_DIR/resource/outfit"

DATA=$(curl -s "$API_URL")
if [[ -z "$DATA" ]]; then
    echo "[ERROR] Could not reach API. Check your connection." >&2
    exit 1
fi

TOTAL=$(echo "$DATA" | jq '[.[]] | length')
echo "[FASTUMA] Found $TOTAL entries. Downloading assets..."
echo ""

# ── BLOCK 6: descargar assets ─────────────────────────────────
COUNT=0
SKIPPED=0
FAILED=0

[[ ! -f "$OUTPUT_JSON" ]] && echo "{}" > "$OUTPUT_JSON"

while IFS= read -r item; do
    chara_id=$(echo "$item" | jq -r '.chara_game_id')
    outfit_id=$(echo "$item" | jq -r '.id')
    gametora=$(echo "$item"  | jq -r '.gametora')
    title=$(echo "$item"     | jq -r '.title')
    name=$(echo "$gametora"  | cut -d'-' -f2- | tr '-' ' ')

    filename="${chara_id}-${outfit_id}.png"
    filepath="$IMG_DIR/$filename"
    img_url="https://gametora.com/images/umamusume/characters/chara_stand_${chara_id}_${outfit_id}.png"

    if [[ ! -f "$filepath" ]]; then
        curl -s -L -o "$filepath" "$img_url"
        # verificar que sea un PNG real, no una página 404
        if [[ ! -s "$filepath" ]] || ! file "$filepath" | grep -q "PNG"; then
            echo "[WARNING] Image not found: $filename"
            rm -f "$filepath"
            FAILED=$((FAILED + 1))
        fi
    else
        SKIPPED=$((SKIPPED + 1))
    fi

    COUNT=$((COUNT + 1))

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

done < <(echo "$DATA" | jq -c '.[]')

# ── BLOCK 7: done ─────────────────────────────────────────────
DOWNLOADED=$((COUNT - SKIPPED - FAILED))
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
echo ""