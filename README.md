# DELTARUNE From Scratch — Chapter 1

This repository is now a **Kristal project**, not a standalone imitation of DELTARUNE's battle system.

The old hand-written LÖVE battle prototype has been removed. Battles now execute inside the actual Kristal engine and use Kristal's real:

- three-member party action selection
- character-specific FIGHT / ACT / MAGIC / ITEM / SPARE / DEFEND buttons
- TP and grazing systems
- party and enemy target selection
- queued Kris, Susie, and Ralsei actions
- attack timing bars
- enemy dialogue
- arena, SOUL, Wave, and Bullet systems
- MERCY, TIRED, Pacify, victory, and battle transitions
- Kristal crash/error handler and traceback screen

The project currently boots directly into a small training encounter so the real battle flow can be tested immediately.

## Run on Windows

Requirements:

- Git for Windows
- LÖVE 11.x

Double-click:

```text
run-kristal.bat
```

The launcher will:

1. clone the official Kristal repository into `.kristal-engine` if needed;
2. update the local Kristal checkout;
3. create a junction from Kristal's `mods` directory to this project;
4. launch Kristal with this project selected.

## Run manually

Clone Kristal, then place this repository inside its `mods` directory using the project ID:

```text
Kristal/
└── mods/
    └── deltarune_from_scratch_ch1/
        ├── mod.json
        ├── mod.lua
        ├── scripts/
        └── assets/
```

From the Kristal directory, run:

```bash
love . --mod deltarune_from_scratch_ch1
```

## Project structure

```text
mod.json
mod.lua
scripts/
├── world/maps/battle_room.lua
├── data/actors/training_dummy.lua
└── battle/
    ├── encounters/training.lua
    ├── enemies/training_dummy.lua
    ├── waves/basic.lua
    └── bullets/smallbullet.lua
assets/sprites/
├── enemies/training_dummy/idle.png
└── bullets/smallbullet.png
```

The encounter, enemy, actor, wave, bullet, and starter sprites are adapted from Kristal's official `mod_template`. See `THIRD_PARTY_NOTICES.md` and `LICENSES/KRISTAL-BSD-3-CLAUSE.txt`.

## Development direction

Chapter 1 content should now be implemented as normal Kristal maps, cutscenes, actors, encounters, enemies, waves, items, and spells. Do not rebuild the battle engine again; extend Kristal's systems instead.
