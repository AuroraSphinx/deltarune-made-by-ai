# Assets

This project uses a Kristal-style asset registry: files are separated by type, scanned recursively, and addressed by extensionless paths.

```text
assets/
├── sprites/      PNG textures and numbered animation frames
├── sounds/       Short WAV, OGG, or MP3 sound effects
├── music/        Streamed WAV, OGG, or MP3 music
├── fonts/        TTF, OTF, or BMFont `.fnt` files
├── shaders/      GLSL, FRAG, or VERT shaders
└── placeholders.lua
```

Git does not preserve empty directories, so each typed directory contains a small README until real assets are added.

## IDs

The asset ID is its path relative to the typed directory, without the extension.

| File | ID |
|---|---|
| `sprites/party/kris/dark/walk/down.png` | `party/kris/dark/walk/down` |
| `sounds/ui/confirm.ogg` | `ui/confirm` |
| `music/chapter1/field.ogg` | `chapter1/field` |
| `fonts/main.ttf` | `main` |
| `shaders/effects/wave.glsl` | `effects/wave` |

Do not include `assets/`, the typed folder name, or the file extension in code.

## Sprite animations

Files ending in `_NUMBER` are grouped in numeric order:

```text
sprites/party/kris/dark/walk/down_1.png
sprites/party/kris/dark/walk/down_2.png
sprites/party/kris/dark/walk/down_10.png
```

All three are available through `party/kris/dark/walk/down`.

```lua
local texture = Assets:getTexture("ui/heart")
local frames = Assets:getFrames("party/kris/dark/walk/down")
local either = Assets:getFramesOrTexture("party/kris/dark/walk/down")

Assets:draw("party/kris/dark/walk/down", x, y, {
    fps = 8,
    centered = false,
})
```

A plain `down.png` remains a single texture. If both a plain texture and numbered frames exist for the same ID, `getTexture` returns the plain texture and `getFrames` returns the animation.

## Audio, fonts, and shaders

```lua
Assets:playSound("ui/confirm", 0.8, 1.0)

local music = Assets:newMusic("chapter1/field", true)
music:play()

local font = Assets:getFont("main", 16)
local shader = Assets:getShader("effects/wave")
```

Sounds are cached as static sources and cloned when played. Music is opened as a streamed source. Fonts and shaders are loaded lazily when first requested.

## Compatibility aliases

The first prototype used short names. These remain mapped to the new paths:

| Old ID | New ID |
|---|---|
| `hero_down` | `party/kris/dark/walk/down` |
| `hero_up` | `party/kris/dark/walk/up` |
| `hero_left` | `party/kris/dark/walk/left` |
| `hero_right` | `party/kris/dark/walk/right` |
| `friend` | `party/susie/dark/walk/down` |
| `dummy` | `world/npcs/training_dummy` |
| `enemy` | `enemies/training_dummy` |

This lets OpenCode or older branches keep running while files migrate to the new layout.

## Runtime fallbacks

`placeholders.lua` contains original temporary sprites. If one of the mapped prototype sprites is missing, the loader generates its placeholder at runtime. Other missing IDs return `nil` from the getter or raise a clear error when passed to `Assets:draw`.

Only commit assets the project is allowed to use and redistribute.
