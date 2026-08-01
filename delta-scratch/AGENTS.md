# AGENTS.md — Delta Scratch (Chapter 1 LÖVE Prototype)

Guidance for humans and AI agents working on this repository. Read this
before touching code.

## What this is

A clean-room, from-scratch **LÖVE 11.x** (Lua) fan prototype inspired by
DELTARUNE Chapter 1: a title screen, overworld with rooms/NPCs/dialogue, and
a Kristal-legacy-based battle system (FIGHT / ACT / ITEM / SPARE / DEFEND,
soul, bullets). It also runs on the web via a real LÖVE-Emscripten port
(love.js), not an HTML5 reimplementation.

## Quickstart

```bash
# Desktop (requires LÖVE 11.5, https://love2d.org)
love .

# Web build (requires node + npm)
# Windows:  build_web.bat web_build
# Linux/mac: ./build_web.sh web_build
python3 -m http.server 8000 -d web_build
# -> open http://localhost:8000
```

## Repository layout

```
main.lua                  LÖVE entry point (load/update/draw/input/resize)
conf.lua                  love.conf — window, identity, LÖVE version (11.4)
build_web.sh / .bat        Pack the game with love.js (Emscripten LÖVE 11.4);
                          .sh for Linux/macOS, .bat for Windows
src/
  game.lua                Game state machine + rendering pipeline + title UI
  world.lua               Rooms, movement, collisions, NPCs, static backgrounds
  dialogue.lua            Typewriter dialogue boxes
  battle.lua              Battle glue (draw hooks); logic is vendored below
  assets.lua              Asset loading: exact-folder sprite frames + animation
                          sets, generated placeholders
  util.lua                clamp/normalize/rect helpers
vendor/kristal_legacy/    Kristal battle engine (battle_base/actions/update/
                          draw.lua) + error handler. Treat as upstream code:
                          patch through src/battle.lua hooks, don't rewrite.
assets/
  chapter-1/sprites/      Game-extracted Chapter 1 PNGs (read-only, ~3k files)
  fonts/                  Determination Mono/Sans TTFs
  placeholders.lua        Runtime-generated fallback sprites (ascii grids)
```

## Rendering pipeline (important — do not regress)

- **Virtual space is 320×240**, but the world is **not** rendered to a 320×240
  canvas anymore. `Game:resize` creates a canvas at the **window's pixel
  size** and `Game:draw` applies `translate(offset) + scale(scale)` before
  drawing the virtual world. The canvas is then blitted 1:1. This is what
  keeps the game sharp instead of blurry/chunky at 720p.
- **Fonts are DPI-scaled, not size-scaled.** `Game:rebuildVirtualFonts`
  creates the 8/10/12px virtual fonts with `dpiscale = internal scale`
  (`love.graphics.newFont(path, size, "normal", dpiscale)`). Glyphs rasterize
  at `size * dpiscale` while layout metrics (`getHeight()`, `printf` widths)
  stay in 320×240 units — so text is razor sharp without breaking layout.
  The `self.fonts` table is **mutated in place** on resize; dialogue/world/
  battle hold references to that same table, so never replace it wholesale.
- **Static room backgrounds are pre-rendered** to 320×240 canvases once
  (`World.ensureBackgrounds`). Per-frame `table.sort`, `setRandomSeed`, and
  hundreds of background rectangles are forbidden — that was the old garbage.
- Scaling modes (options menu): `smooth` = linear filter, `sharp` = nearest
  (default), `pixel` = nearest + integer scale. `Game:applyRenderFilter`
  propagates the mode to images, fonts, canvases and world backgrounds.
- The title/options UI is drawn in **native window space** (`drawTitleNative`
  + `nativeFonts`), not through the virtual transform.

## Code conventions

- Lua 5.1 (LuaJIT / LÖVE). No external libraries.
- State machine lives in `Game.state` (`title` / `world` / `battle`) and in
  battle sub-states (`ACTIONSELECT`, `ENEMYSELECT`, `ATTACKING`,
  `ENEMYDIALOGUE`, `DEFENDING`, ...). Route input through the existing
  `keypressed` chains — don't add parallel input handling.
- Hot path rules (every frame, `update`/`draw`):
  - No table allocations per frame where avoidable (cache rooms, NPC order,
    star fields at load time).
  - No `table.sort` in draw (NPC order is pre-sorted at module load).
  - No `love.math.setRandomSeed` per frame.
  - No font/canvas creation per frame (resize only).
- `conf.lua` declares `t.version` from `config.love_version` ONLY when a
  desktop OS is positively detected (love.system isn't ready during conf on
  web); otherwise it declares 11.4 to match the love.js runtime and avoid
  the compatibility dialog. Don't "simplify" this back to a fixed 11.5.
- Chapter sprite files under `assets/chapter-1/` are large and read-only.
  `assets.lua` addresses them by **exact sprite folder name** (e.g.
  `spr_krisd`, `spr_jigsawry_idle`) and loads every `_N.png` frame as a
  looping animation; `registerAnimationSet` maps named animations
  (`idle`/`hurt`/`spared`). Missing folders fall back to placeholders.
- **Never match sprite names by substring** — the old pattern scorer picked
  `spr_bakesale_rudinn` (a Rudinn at a bake sale) as "the Rudinn sprite"
  and it stood in for the battle enemy. Exact folders only.

## Battle HUD (Deltarune style) — where things live

`src/battle.lua` overrides the vendored renderer: green battle box
(`drawArena`), party positions (`getPartyPositions`: Kris front-left, Susie
mid, Ralsei back), blue TP gauge bottom-left (`drawTensionBar`), 2x2 yellow
FIGHT/ACT/ITEM/SPARE buttons bottom-right (`drawCommandButtons`), enemy
name/HP/MERCY top-left (`drawEnemyInfo` — hooked into `draw()` because the
vendored draw never called it), party status stacked top-right
(`drawStatusBoxes`), white-bordered dialogue box (`drawDialogueBox`).
The arena rect comes from `ARENA_DEFAULT` in
`vendor/kristal_legacy/battle_base.lua`; party actions (no DEFEND) live in
`PARTY_DEFS` there too.

## Adding content

- **Room**: add a table to `rooms` in `src/world.lua` (walls as rects,
  exits, npcs, spawn). Rooms are drawn by `backgrounds[roomName]`; to give a
  room custom art, add a background draw function + pre-render it in
  `ensureBackgrounds` (both field and hall patterns are there).
- **NPC / dialogue**: add an NPC table (`id`, `sprite`, `name`, `x/y/w/h`,
  `lines`) — optionally `battle = true` to start a battle after dialogue.
- **Sprite**: point an asset name at an exact folder in `assets.lua`
  (`registerFrames` or `registerAnimationSet`), e.g.
  `registerFrames("hero_down", "spr_krisd", {fps = 7})` — the folder's
  `_N.png` frames become the animation. `assets/placeholders.lua` fills in
  when a folder is missing.
- **Animation timing**: pass `options.animTime` to `Assets:draw`; the frame
  is `floor(animTime * fps) % #frames`. World timers live in `world.lua`
  (`npc.animTimer`, `player.animTimer`); battle sprites use the engine's
  `member.animationTimer` / `enemy.animationTimer`.

## Controls

| Input | Action |
|---|---|
| Arrows / WASD | Move |
| Shift | Run |
| Z / Enter / Space | Confirm / interact / advance text |
| X / Escape | Cancel / back |
| B | Start battle test (overworld) |
| F3 (hold) | Collision debug |
| F11 | Fullscreen |

## Web build notes

- `build_web.sh` (Linux/macOS) and `build_web.bat` (Windows, PowerShell —
  no Python required) install `love.js@11.4.1` **locally into `.lovejs/`**
  (gitignored) and invoke it with `node` directly — **never via npx** (npx on
  Windows can spawn the bare `.bin/love.js` shim, which Windows Script Host
  tries to run as JScript → "Invalid character", error 800A03F6).
- Both scripts **auto-detect a desktop LÖVE install** (PATH / common paths /
  registry on Windows) and use it to package `game.love` and optionally
  launch the desktop version. The web build itself does not use desktop
  LÖVE — `love.wasm` is LÖVE compiled to WebAssembly and ships in the build.
- They use the love.js **compat** runtime so the game runs on any host
  without COOP/COEP/SharedArrayBuffer headers (itch.io, GitHub Pages, etc.).
- `-m 268435456` is the WASM heap; `game.data` (~21 MB) is the packed game.
- The `index.html` favicon links to the repo's `favicon.svg` (copied in by
  both build scripts) to keep the browser console clean.
- `conf.lua` version is intentionally 11.4 — see above.
- Desktop `love .` still runs the same code with LÖVE 11.5.

## Verifying changes (web)

Serve the build and drive it headlessly (Chromium) to confirm boot and
gameplay: title → Z → world → B → battle → Z (FIGHT) → Z (target) →
~7 s → soul phase (red pixels in the arena) → bullets. Check the browser
console for Lua tracebacks and 404s. The love.js loading canvas must
disappear (display: none) — that means the engine booted.
To confirm animations: take two screenshots ~0.1–0.15 s apart and diff the
player/enemy regions — they must differ (walk cycle, battle idle loop).

## Troubleshooting

- **"This game indicates it was made for version '11.5'..."** — conf.lua
  version must be `11.4` for the web runtime. Don't bump it.
- **Build scripts trim assets**: the repo keeps all ~3,000 extracted PNGs
  (~31 MB) but builds stage ONLY the sprite folders referenced by
  `src/assets.lua` (list kept in sync inside `build_web.sh` / `build_web.bat`).
  This keeps `game.love` (~150 KB) and the web build (~5 MB) small. If you
  add a sprite folder to `assets.lua`, add it to the build script's list too.
- **`Compress-Archive : .love não é um formato...`** — PowerShell only lets
  Compress-Archive write `.zip`. The build script packages to `game.zip` and
  renames it to `game.love` (a .love file is a zip) — don't "fix" it by
  writing to game.love directly.
- **`File main.lua does not exist on disk` (web)** — the build fed love.js a
  *directory* instead of a `.love` file. On Windows the tool registers files
  with backslash paths (`\main.lua`) and the game can't find main.lua. The
  build scripts always package `game.love` first and pass that single file —
  a `.love` is a zip, so its internal paths are always forward-slash. If you
  see this, rebuild with the current scripts (game.love is fed to love.js),
  then hard-refresh the browser page (Ctrl+F5) — love.js caches game.data.
- **Blank screen** — reload; the love.js page warns about this for
  slow/streaming hosts. Otherwise check the console: wasm fetch failed,
  game.data 404, or a Lua error in `love.load`.
- **Blurry or chunky text** — `rebuildVirtualFonts` dpiscale must track the
  internal scale; a regression here makes world text soft or blocky.
