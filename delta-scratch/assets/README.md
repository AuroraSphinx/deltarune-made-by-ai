# Assets

`chapter-1/sprites/` holds PNGs extracted from the game (read-only, ~3k
files). `src/assets.lua` loads them by **exact sprite folder name** — every
`_N.png` frame in a folder becomes a looping animation, and some sprites are
registered as named animation sets (`idle` / `hurt` / `spared`).

Map used by the game:

| Asset name          | Sprite folder           | Usage                          |
|---------------------|-------------------------|--------------------------------|
| hero_down/up/l/r    | spr_krisd/u/l/r         | Kris overworld walk cycle      |
| hero_battle         | spr_krisb_idle          | Kris battle idle               |
| friend              | spr_susied              | Susie overworld NPC            |
| friend_battle       | spr_susieb_idle         | Susie battle idle              |
| ralsei              | spr_ralseib_idle        | Ralsei battle idle             |
| dummy               | spr_dummynpc            | Training Dummy NPC             |
| architect           | spr_darklancer          | Room Architect NPC             |
| enemy (idle/hurt/spared) | spr_jigsawry_idle/hurt/spared | Battle enemy          |

When a folder is missing, `assets/placeholders.lua` provides an original
runtime-generated fallback sprite. Never match sprite names by substring —
that is how `spr_bakesale_rudinn` (a Rudinn at a bake sale) once slipped in
as the battle enemy.
