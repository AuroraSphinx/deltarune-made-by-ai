# Vendored Kristal battle code

This directory is a standalone adaptation of Kristal's legacy battle engine,
not a Kristal mod and not a replacement for this repository's game project.

Pinned upstream source:

- Repository: `KristalTeam/Kristal`
- Commit: `d3f87dad18bc5c1fdce0ecd90511a5ff55476ce7`
- License: BSD-3-Clause

The port keeps Kristal's battle-state and action-queue shape (`ACTIONSELECT`,
`MENUSELECT`, `ENEMYSELECT`, `PARTYSELECT`, `ACTIONS`, `ATTACKING`,
`ENEMYDIALOGUE`, `DIALOGUEEND`, `DEFENDING`, `VICTORY`, `TRANSITIONOUT`) and
adapts rendering/input to the existing 320x240 standalone LÖVE project API.

The repository's overworld, title screen, assets, `src/game.lua`, and launch
flow remain independent from Kristal.
