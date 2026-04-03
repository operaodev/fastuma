#!/usr/bin/env bash
# fastuma — fastuma.sh
# Elige personaje/outfit y ejecuta fastfetch con esa imagen.
# Lives at ~/.local/share/fastuma/fastuma.sh
# Run as: fastuma

set -euo pipefail

# ── paths ─────────────────────────────────────────────────────
APP_DIR="$HOME/.local/share/fastuma"
CONF_FILE="$APP_DIR/fastuma.conf"

[[ "${1:-}" == "--conf" && -n "${2:-}" ]] && CONF_FILE="$2"

# ── load config ───────────────────────────────────────────────
[[ ! -f "$CONF_FILE" ]] && { echo "[ERROR] Config not found: $CONF_FILE" >&2; exit 1; }

RESOURCE="outfit"
RANDOM_CHARA="true"
RANDOM_OUTFIT="true"
FIXED_CHARA_ID=""
FASTFETCH_CONFIG="$HOME/.config/fastfetch/config.jsonc"
IMAGE_PROTOCOL="kitty"

while IFS='=' read -r key val; do
    [[ "$key" =~ ^(RESOURCE|RANDOM_CHARA|RANDOM_OUTFIT|FIXED_CHARA_ID|FASTFETCH_CONFIG|IMAGE_PROTOCOL)$ ]] \
        && declare "$key"="${val//\"/}"
done < <(grep -v '^#' "$CONF_FILE" | grep -v '^$')

# ── resolve paths ─────────────────────────────────────────────
JSON="$APP_DIR/uma_grouped.json"
IMG_DIR="$APP_DIR/resource/${RESOURCE:-outfit}"
FF_CONFIG="${FASTFETCH_CONFIG/\~/$HOME}"
TMP="/tmp/fastuma-$$.jsonc"

# ── validate ──────────────────────────────────────────────────
[[ ! -f "$JSON" ]]      && { echo "[ERROR] Run install.sh first." >&2; exit 1; }
[[ ! -f "$FF_CONFIG" ]] && { echo "[ERROR] Fastfetch config not found: $FF_CONFIG" >&2; exit 1; }
[[ ! -d "$IMG_DIR" ]]   && { echo "[ERROR] Image dir not found: $IMG_DIR" >&2; exit 1; }

# ── pick character ────────────────────────────────────────────
if [[ "${RANDOM_CHARA:-true}" == "true" ]]; then
    CHARA_ID=$(jq -r 'keys[]' "$JSON" | shuf -n 1)
else
    CHARA_ID="${FIXED_CHARA_ID}"
    [[ -z "$CHARA_ID" ]] && { echo "[ERROR] FIXED_CHARA_ID is empty in config." >&2; exit 1; }
fi

NAME=$(jq -r --arg cid "$CHARA_ID" '.[$cid].name // empty' "$JSON")
[[ -z "$NAME" ]] && { echo "[ERROR] Character '$CHARA_ID' not found in JSON." >&2; exit 1; }

# ── pick outfit ───────────────────────────────────────────────
if [[ "${RANDOM_OUTFIT:-true}" == "true" ]]; then
    OUTFIT_B64=$(jq -r --arg cid "$CHARA_ID" '.[$cid].outfits[] | @base64' "$JSON" | shuf -n 1)
else
    OUTFIT_B64=$(jq -r --arg cid "$CHARA_ID" '.[$cid].outfits[0] | @base64' "$JSON")
fi

_decode() { echo "$OUTFIT_B64" | base64 --decode | jq -r "$1"; }
OUTFIT_TITLE=$(_decode '.title')
OUTFIT_IMAGE=$(_decode '.image')
IMAGE_PATH="$IMG_DIR/$OUTFIT_IMAGE"

[[ ! -f "$IMAGE_PATH" ]] && { echo "[ERROR] Image not found: $IMAGE_PATH. Run install.sh." >&2; exit 1; }

# ── patch config y ejecutar ───────────────────────────────────
TITLE="${NAME^^} · ${OUTFIT_TITLE^^}"

cp "$FF_CONFIG" "$TMP"
sed -i "s|\"source\":[ ]*\"[^\"]*\"|\"source\": \"$IMAGE_PATH\"|" "$TMP"
sed -i '/\/\/ fastuma-title/d' "$TMP"
sed -i '/^[[:space:]]*"modules"[[:space:]]*:[[:space:]]*\[/a\
        { "type": "custom", "format": "'"$TITLE"'" }, // fastuma-title' "$TMP"

fastfetch --config "$TMP"
rm -f "$TMP"