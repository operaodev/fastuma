#!/usr/bin/env fish
# fastuma — fastuma.fish
# Elige personaje/outfit y ejecuta fastfetch con esa imagen.
# Lives at ~/.local/share/fastuma/fastuma.fish
# Run as: fastuma

# ── paths ─────────────────────────────────────────────────────
set APP_DIR  "$HOME/.local/share/fastuma"
set CONF_FILE "$APP_DIR/fastuma.conf"

if test (count $argv) -ge 2 -a "$argv[1]" = "--conf"
    set CONF_FILE $argv[2]
end

# ── load config ───────────────────────────────────────────────
if not test -f $CONF_FILE
    echo "[ERROR] Config not found: $CONF_FILE" >&2; exit 1
end

# defaults
set RESOURCE           "outfit"
set RANDOM_CHARA       "true"
set RANDOM_OUTFIT      "true"
set FIXED_CHARA_ID     ""
set FIXED_OUTFIT_INDEX "0"
set FASTFETCH_CONFIG   "$HOME/.config/fastfetch/config.jsonc"
set IMAGE_PROTOCOL     "kitty"

# parse config file — a prueba de balas para Fish
cat $CONF_FILE | while read -l line
    set line (string trim $line)
    if string match -qr '^#' "$line"; or test -z "$line"
        continue
    end
    
    set parts (string split -m1 '=' "$line")
    set key (string trim "$parts[1]")
    
    # Trim seguro: limpiamos espacios y luego quitamos comillas paso por paso
    set val (string trim "$parts[2]")
    set val (string trim -c '"' "$val")
    set val (string trim -c "'" "$val")
    
    switch "$key"
        case RESOURCE;           set RESOURCE "$val"
        case RANDOM_CHARA;       set RANDOM_CHARA "$val"
        case RANDOM_OUTFIT;      set RANDOM_OUTFIT "$val"
        case FIXED_CHARA_ID;     set FIXED_CHARA_ID "$val"
        case FIXED_OUTFIT_INDEX; set FIXED_OUTFIT_INDEX "$val"
        case FASTFETCH_CONFIG;   set FASTFETCH_CONFIG "$val"
        case IMAGE_PROTOCOL;     set IMAGE_PROTOCOL "$val"
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
    # Añadido `tojson` para evitar que jq colapse al codificar objetos a base64
    set OUTFIT_B64 (jq -r --arg cid "$CHARA_ID" '.[$cid].outfits[] | tojson | @base64' $JSON | shuf -n 1)
else
    if test -z "$FIXED_OUTFIT_INDEX"
        set FIXED_OUTFIT_INDEX 0
    end
    
    set OUTFIT_B64 (jq -r --arg cid "$CHARA_ID" --argjson idx "$FIXED_OUTFIT_INDEX" '.[$cid].outfits[$idx] | tojson | @base64' $JSON)
    
    # Manejo de error si el índice es inválido (jq devuelve null en base64 = bnVsbA==)
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
set TITLE (string upper "$NAME")" · "(string upper "$OUTFIT_TITLE")

# ── patch fastfetch config ────────────────────────────────────
cp $FF_CONFIG $TMP

# Reemplazo de sed optimizado que evita los bugs de saltos de línea de Fish
sed -i "s|\"source\":[ ]*\"[^\"]*\"|\"source\": \"$IMAGE_PATH\"|" $TMP
sed -i '/\/\/ fastuma-title/d' $TMP
sed -i "s|^\([[:space:]]*\"modules\"[[:space:]]*:[[:space:]]*\[\)|\1\n        { \"type\": \"custom\", \"format\": \"$TITLE\" }, // fastuma-title|" $TMP

# ── run ───────────────────────────────────────────────────────
fastfetch --config $TMP
rm -f $TMP