#!/usr/bin/env bash
# Build the LÖVE-on-Web (Emscripten) bundle into web_build/.
#
# Requirements: node + npm + zip. The love.js CLI is installed ONCE into
# .lovejs/ (gitignored) and invoked directly with node - no npx needed.
# On Windows use build_web.bat instead.
#
# ASSET TRIMMING: the repo's assets/ holds ~3,000 extracted Chapter 1 PNGs
# (~31 MB) but the game only loads ~20 sprite folders. The build stages ONLY
# those referenced folders, so game.love and the web build stay small and
# load fast. The repo's full assets/ is untouched. If you add a sprite
# folder to src/assets.lua, add it to SPRITES below as well.
#
# A local `love` binary is detected to run the game locally (--run
# auto-launches); the web build itself uses love.wasm (LÖVE compiled to
# WebAssembly), which a desktop LÖVE cannot produce.
#
# The compat runtime is used so the game runs on any host without needing
# COOP/COEP (SharedArrayBuffer) response headers.
set -euo pipefail
cd "$(dirname "$0")"

OUT="${1:-web_build}"
AUTORUN=0
[ "${2:-}" = "--run" ] && AUTORUN=1
TITLE="DELTA SCRATCH - Chapter 1"
MEMORY=268435456 # 256 MB WASM heap
LOVEJS=".lovejs"

# Sprite folders referenced by src/assets.lua (keep in sync!).
SPRITES="spr_krisd spr_krisu spr_krisl spr_krisr spr_susied spr_dummynpc \
spr_darklancer spr_krisb_idle spr_susieb_idle spr_ralseib_idle \
spr_jigsawry_idle spr_jigsawry_hurt spr_jigsawry_spared \
IMAGE_LOGO_CENTER IMAGE_MENU bg_battleback1"

echo "=== Delta Scratch web build ==="

# --- [1/5] Detect desktop LÖVE ----------------------------------------------
LOVE_BIN=""
if command -v love >/dev/null 2>&1; then
    LOVE_BIN="$(command -v love)"
elif [ -x /usr/bin/love ]; then
    LOVE_BIN=/usr/bin/love
fi
if [ -n "$LOVE_BIN" ]; then
    echo "[1/5] Detected LÖVE: $LOVE_BIN"
else
    echo "[1/5] LÖVE not found - desktop launch skipped (install from https://love2d.org)"
fi

# --- [2/5] love.js tool ------------------------------------------------------
if [ ! -f "$LOVEJS/node_modules/love.js/index.js" ]; then
    echo "[2/5] Installing love.js@11.4.1 into $LOVEJS/ ... (first run only)"
    mkdir -p "$LOVEJS"
    npm install --prefix "$LOVEJS" love.js@11.4.1
fi

# --- [3/5] stage trimmed project + package game.love -------------------------
echo "[3/5] Staging trimmed project + packaging game.love..."
if ! command -v zip >/dev/null 2>&1; then
    echo "zip not found - install it (apt install zip / brew install zip) and retry."
    exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE/assets/fonts" "$STAGE/assets/chapter-1/sprites"
cp main.lua conf.lua config.lua favicon.svg icon.png bigicon.png "$STAGE/"
cp -r src vendor "$STAGE/"
cp -r assets/fonts assets/placeholders.lua assets/README.md "$STAGE/assets/"
for d in $SPRITES; do
    if [ -d "assets/chapter-1/sprites/$d" ]; then
        cp -r "assets/chapter-1/sprites/$d" "$STAGE/assets/chapter-1/sprites/"
    else
        echo "  WARNING: sprite folder missing: $d (placeholder will be used)"
    fi
done

rm -f game.love
(cd "$STAGE" && zip -qr "$OLDPWD/game.love" .)
echo "game.love ready - run it with: ${LOVE_BIN:-love} game.love"

# --- release artifacts (config.build) ---------------------------------------
mkdir -p build/release
cp game.love build/release/deltarune.love
echo "Release archive: build/release/deltarune.love"
if [ -n "$LOVE_BIN" ] && [ "${LOVE_BIN##*/}" = "love" ] && [ -f "$(dirname "$LOVE_BIN")/love.exe" ]; then
    # Windows LÖVE on WSL/CI: fuse love.exe + game.love into a self-contained exe.
    LOVE_DIR="$(dirname "$LOVE_BIN")"
    cat "$LOVE_DIR/love.exe" game.love > build/release/deltarune.exe
    cp "$LOVE_DIR"/*.dll build/release/ 2>/dev/null || true
    echo "Release exe: build/release/deltarune.exe"
fi

# --- [4/5] build web from the .love file -------------------------------------
echo "[4/5] Building with LÖVE 11.4 (Emscripten)..."
node "$LOVEJS/node_modules/love.js/index.js" -c -t "$TITLE" -m "$MEMORY" game.love "$OUT"

# --- [5/5] favicon + done ----------------------------------------------------
echo "[5/5] Linking favicon..."
cp favicon.svg "$OUT/"
python3 - "$OUT/index.html" <<'PY'
import sys
path = sys.argv[1]
html = open(path).read()
if 'rel="icon"' not in html:
    link = '<link rel="icon" href="favicon.svg">'
    html = html.replace('<title>', link + '\n    <title>', 1)
    open(path, 'w').write(html)
print("favicon linked")
PY

echo "Web build written to: $OUT"
echo "Serve it with:  python3 -m http.server 8000 -d $OUT"
if [ -n "$LOVE_BIN" ]; then
    if [ "$AUTORUN" = "1" ]; then
        echo "Launching desktop version with your LÖVE..."
        "$LOVE_BIN" .
    else
        read -r -p "Launch the desktop game now with your LÖVE? [y/N] " RUN
        if [ "${RUN:-}" = "y" ] || [ "${RUN:-}" = "Y" ]; then
            "$LOVE_BIN" .
        fi
    fi
fi
