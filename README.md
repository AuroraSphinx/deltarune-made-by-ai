# DELTA SCRATCH — Chapter 1 LÖVE2D Prototype

A from-scratch LÖVE2D codebase for rebuilding a Chapter 1-style game room by room.

Included modules:

- crisp 320×240 virtual-resolution and scaling code
- overworld movement, collisions, NPCs, dialogue, and room exits
- a battle prototype with FIGHT, ACT, SPARE, FLEE, HP, and bullet patterns
- a Kristal-style asset registry with automatic folder scanning
- numbered PNG animation support and placeholder fallbacks

## Current development entry point

OpenCode currently uses `main.lua` as a small WASD rectangle test. The test now calls `Assets:load()` at startup, so the new asset system remains active without reverting OpenCode's work. The fuller prototype modules are still available under `src/` and can be reconnected later.

## Run it

Install [LÖVE 11.5](https://love2d.org/) and run:

```bash
love .
```

On Windows, you can also drag the project folder onto `love.exe`.

Current test controls: **WASD** moves the rectangle.

## Kristal-style assets

Assets are separated by type and referenced by extensionless IDs. The loader recursively scans these directories at startup:

```text
assets/
├── sprites/
├── sounds/
├── music/
├── fonts/
├── shaders/
└── placeholders.lua
```

For example, this file:

```text
assets/sprites/party/kris/dark/walk/down.png
```

is loaded as:

```lua
Assets:getTexture("party/kris/dark/walk/down")
Assets:draw("party/kris/dark/walk/down", x, y)
```

### Animated sprites

Numbered PNGs are grouped automatically:

```text
assets/sprites/party/kris/dark/walk/down_1.png
assets/sprites/party/kris/dark/walk/down_2.png
assets/sprites/party/kris/dark/walk/down_3.png
```

They become one animation ID:

```lua
local frames = Assets:getFrames("party/kris/dark/walk/down")
Assets:draw("party/kris/dark/walk/down", x, y, {fps = 8})
```

A non-numbered `down.png` is treated as a single texture. Existing prototype IDs such as `hero_down`, `friend`, `dummy`, and `enemy` remain aliases, so older gameplay code does not break.

### Other asset types

```lua
Assets:playSound("ui/confirm")
local music = Assets:newMusic("chapter1/field", true)
local font = Assets:getFont("main", 16)
local shader = Assets:getShader("effects/wave")
```

Those IDs correspond to files beneath `assets/sounds`, `assets/music`, `assets/fonts`, and `assets/shaders` with their extensions removed.

See [`assets/README.md`](assets/README.md) for the complete layout and naming rules.

## Project layout

```text
conf.lua                  LÖVE window configuration
main.lua                  current OpenCode test entry point
src/game.lua              canvas, states, scaling, and top-level flow
src/world.lua             rooms, movement, collisions, NPCs, exits
src/dialogue.lua          dialogue box and typewriter behavior
src/battle.lua            battle menu, attacks, soul, bullets, HP
src/assets.lua            Kristal-style asset scanner and registry
src/util.lua              shared math and collision helpers
assets/placeholders.lua   original runtime-generated fallback sprites
```

## Recommended next milestones

1. Add a reusable actor/animation class that stores animation state per character.
2. Reconnect the full game state after the rectangle test is finished.
3. Replace collision rectangles with a Tiled map loader.
4. Add party followers and room-specific encounter scripts.
5. Add save points and JSON save data.
6. Add music and sound hooks through the new asset registry.

## Notice

The source code and placeholder art in this repository are original project material. Only add assets that your project is allowed to use and distribute.
