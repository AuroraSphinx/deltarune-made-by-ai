# DELTA SCRATCH — Chapter 1 LÖVE2D Prototype

A clean-room, from-scratch LÖVE2D foundation for building a Chapter 1-inspired fan project with a friend.

This repository currently includes:

- crisp 320×240 virtual resolution with integer scaling
- title screen and state management
- overworld movement and collision rectangles
- reusable NPC/dialogue system with typewriter text
- two original test rooms
- a battle prototype with FIGHT, ACT, SPARE, and FLEE
- movable red soul, invulnerability frames, HP, and three bullet patterns
- runtime-generated original placeholder sprites
- optional external PNG loading with automatic placeholder fallback

## Run it

Install [LÖVE 11.5](https://love2d.org/) and run this folder:

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

## Adding legally obtained sprite PNGs

The project never downloads or redistributes DELTARUNE's proprietary assets. When a supported file is absent, an original placeholder is generated from `assets/placeholders.lua`.

Place your own legally obtained PNG files at these exact paths:

```text
assets/
├── characters/
│   ├── kris/
│   │   ├── idle_down.png
│   │   ├── idle_up.png
│   │   ├── idle_left.png
│   │   └── idle_right.png
│   └── susie/
│       └── idle_down.png
├── enemies/
│   └── training_dummy.png
└── npcs/
    └── training_dummy.png
```

PNG files are loaded at their native size. Use nearest-neighbor-friendly pixel art and avoid filtered resizing.

## Project layout

```text
conf.lua                  LÖVE window configuration
main.lua                  LÖVE callbacks
src/game.lua              canvas, states, scaling, and top-level flow
src/world.lua             rooms, movement, collisions, NPCs, exits
src/dialogue.lua          dialogue box and typewriter behavior
src/battle.lua            battle menu, attacks, soul, bullets, HP
src/assets.lua            optional PNG loader and fallback handling
src/util.lua              shared math and collision helpers
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
