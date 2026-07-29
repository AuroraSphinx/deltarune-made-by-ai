# DELTA SCRATCH — Chapter 1 LÖVE2D Prototype

A from-scratch LÖVE2D foundation for rebuilding a Chapter 1-style game room by room.

Current features:

- crisp 320×240 virtual resolution with integer scaling
- title screen and state management
- overworld movement, collisions, NPCs, and room exits
- typewriter dialogue boxes
- a battle prototype with FIGHT, ACT, SPARE, and FLEE
- red SOUL movement, HP, invulnerability frames, and bullet patterns
- a Kristal-style asset registry with automatic folder scanning
- numbered PNG animation support and placeholder fallbacks

## Run it

Install [LÖVE 11.5](https://love2d.org/) and run:

```bash
love .
```

On Windows, you can also drag the project folder onto `love.exe`.

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
main.lua                  LÖVE callbacks
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
2. Replace collision rectangles with a Tiled map loader.
3. Add party followers and room-specific encounter scripts.
4. Add save points and JSON save data.
5. Build Chapter 1 scenes one room at a time.
6. Add music and sound hooks through the new asset registry.

## Notice

The source code and placeholder art in this repository are original project material. Only add assets that your project is allowed to use and distribute.
