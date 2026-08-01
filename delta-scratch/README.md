# DELTA SCRATCH — Chapter 1 LÖVE2D Prototype

A clean-room, from-scratch LÖVE2D foundation for building a Chapter 1-inspired fan project with a friend. Runs on desktop (LÖVE 11.x) **and in the browser** (real LÖVE compiled to WebAssembly via love.js — not an HTML5 reimplementation).

This repository currently includes:

- title screen and state management (native-resolution UI)
- overworld movement and collision rectangles, two test rooms
- reusable NPC/dialogue system with typewriter text
- a battle system with FIGHT, ACT, ITEM, SPARE, DEFEND, movable red soul, invulnerability frames, HP, and three bullet patterns
- real animated Chapter 1 sprites: Kris walk cycles, battle idles for the party, and an animated Jigsawry battle enemy (idle/spared loops)
- Deltarune-style battle HUD: green battle box, party on the left (Kris/Susie/Ralsei), yellow FIGHT/ACT/ITEM/SPARE buttons, blue TP gauge, enemy HP + MERCY top-left, party status top-right
- `config.lua` for all settings (window branding, identity, paths, display), with generated `icon.png` / `bigicon.png` window icons
- ready-to-play `build/release/`: `deltarune.love` (drag onto love.exe) and, on Windows, a fused self-contained `deltarune.exe`
- high-DPI rendering: the world draws at native window resolution, so text and UI stay razor sharp instead of blurry or chunky

## Run it

**Desktop** — install [LÖVE 11.5](https://love2d.org/) and run this folder:

```bash
love .
```

**Web** — requires node + npm:

**Windows:**
```bat
build_web.bat web_build         :: packs the game with love.js (LÖVE 11.4 → WASM)
python -m http.server 8000 -d web_build
:: open http://localhost:8000
```

The build scripts auto-detect your desktop LÖVE install (PATH, Program Files,
registry). They don't use it for the web build — browsers run `love.wasm`
(LÖVE compiled to WebAssembly), which desktop LÖVE can't generate — but they
use it to package a ready-to-play **`game.love`** (drag it onto love.exe) and
offer to launch the desktop game (`build_web.bat web_build --run` auto-launches).

**Linux/macOS:**
```bash
./build_web.sh web_build        # packs the game with love.js (LÖVE 11.4 → WASM)
python3 -m http.server 8000 -d web_build
# open http://localhost:8000
```

The web build uses the love.js **compat** runtime, so it works on any host (GitHub Pages, itch.io, etc.) without special COOP/COEP headers.

## Controls

| Input | Action |
|---|---|
| Arrow keys / WASD | Move |
| Left or right Shift | Run |
| Z / Enter / Space | Confirm or interact |
| X / Escape | Cancel where supported |
| B | Start the battle test |
| F3 | Hold to show collision geometry |
| F11 | Toggle fullscreen |

## Sprites

Sprites load from `assets/chapter-1/sprites/<folder>/` by exact folder name. Every `_N.png` frame in a folder becomes a looping animation (walk cycles, battle idles), and the battle enemy uses named animation sets (`idle` / `hurt` / `spared`). See `assets/README.md` for the asset-name ↔ folder map.

When a folder is missing, an original placeholder is generated from `assets/placeholders.lua` — the project never downloads or redistributes DELTARUNE's proprietary assets.

## Project layout

```text
conf.lua                  LÖVE window configuration (version 11.4 — matches love.js)
main.lua                  LÖVE callbacks
build_web.sh              web build script (love.js / Emscripten)
AGENTS.md                 contributor + AI-agent guide
src/game.lua              states, high-DPI rendering pipeline, title UI
src/world.lua             rooms, movement, collisions, NPCs, pre-rendered backgrounds
src/dialogue.lua          dialogue box and typewriter behavior
src/battle.lua            battle glue (logic vendored under vendor/kristal_legacy/)
src/assets.lua            Chapter 1 sprite picker + placeholder fallback
src/util.lua              shared math and collision helpers
vendor/kristal_legacy/    Kristal battle engine + error handler
assets/placeholders.lua   original runtime-generated placeholder sprites
```

## Recommended next milestones

1. Replace collision rectangles with a Tiled map loader.
2. Add animated sprite sheets and a reusable animation class.
3. Add party followers and room-specific encounter scripts.
4. Add save points and JSON save data.
5. Rebuild Chapter 1 scenes one room at a time using original code and legally obtained local assets.
6. Add original or properly licensed music and sound effects.

## Asset and code notice

The source code and placeholder art in this repository are original project material. DELTARUNE names, characters, artwork, music, dialogue, and other game assets belong to their respective rights holders and are not included here.
