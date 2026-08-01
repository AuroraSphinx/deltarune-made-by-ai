local PlaceholderData = require("assets.placeholders")

local configOk, CONFIG = pcall(require, "config")
if not configOk then
    CONFIG = {}
end

local Assets = {
    images = {},
    chapterSources = {},
}

local currentFilter = "nearest"
local CHAPTER_ROOT = (CONFIG.paths and CONFIG.paths.chapter1) or "assets/chapter-1/sprites"

local palette = {
    ["."] = {0, 0, 0, 0},
    H = {0.09, 0.10, 0.18, 1},
    F = {0.72, 0.78, 0.90, 1},
    E = {0.10, 0.12, 0.20, 1},
    B = {0.17, 0.34, 0.68, 1},
    C = {0.35, 0.85, 0.92, 1},
    L = {0.08, 0.10, 0.17, 1},
    P = {0.72, 0.35, 0.80, 1},
    G = {0.18, 0.62, 0.45, 1},
    W = {0.92, 0.94, 1.00, 1},
    Y = {0.98, 0.83, 0.25, 1},
    O = {0.83, 0.42, 0.12, 1},
    K = {0.08, 0.08, 0.10, 1},
}

local function applyFilter(image, forcedFilter)
    local filter = forcedFilter or currentFilter
    image:setFilter(filter, filter)
end

local function imageFromGrid(rows)
    local height = #rows
    local width = #rows[1]
    local imageData = love.image.newImageData(width, height)

    for y = 1, height do
        assert(#rows[y] == width, "Placeholder rows must all have the same width")
        for x = 1, width do
            local key = rows[y]:sub(x, x)
            local color = palette[key]
            assert(color, "Unknown placeholder palette key: " .. key)
            imageData:setPixel(x - 1, y - 1, color[1], color[2], color[3], color[4])
        end
    end

    local image = love.graphics.newImage(imageData)
    applyFilter(image)
    return image
end

-- Fallback placeholder grid for a sprite name, reusing a similar placeholder
-- when the exact one doesn't exist.
local PLACEHOLDER_FALLBACKS = {
    hero_battle = "hero_down",
    friend_battle = "friend",
    ralsei = "friend",
    architect = "dummy",
}

local function placeholderGrid(name)
    return PlaceholderData[name] or PlaceholderData[PLACEHOLDER_FALLBACKS[name]] or PlaceholderData.dummy
end

-- ---------------------------------------------------------------------------
-- Sprite loading. Sprites are addressed by their EXACT extracted folder name
-- (e.g. "spr_krisd", "spr_jigsawry_idle") and every _N.png frame inside is
-- loaded. Never guess by substring: that is how spr_bakesale_rudinn ended up
-- standing in for the battle enemy.
-- ---------------------------------------------------------------------------

local function sortedPngPaths(folder)
    local root = CHAPTER_ROOT .. "/" .. folder
    local info = love.filesystem.getInfo(root)
    if not info or info.type ~= "directory" then return nil end

    local names = {}
    for _, name in ipairs(love.filesystem.getDirectoryItems(root)) do
        if name:lower():sub(-4) == ".png" then
            names[#names + 1] = name
        end
    end
    table.sort(names)

    local paths = {}
    for _, name in ipairs(names) do
        paths[#paths + 1] = root .. "/" .. name
    end
    return paths
end

local function loadImages(paths)
    local images = {}
    for _, path in ipairs(paths) do
        local ok, image = pcall(love.graphics.newImage, path)
        if ok then
            applyFilter(image)
            images[#images + 1] = image
        end
    end
    return images
end

local function newEntry(frames, fps, placeholder, source, scale)
    return {
        image = frames[1],
        frames = frames,
        fps = fps or 8,
        placeholder = placeholder or false,
        source = source,
        scale = scale or 1,
        lockedFilter = nil,
        animations = nil,
    }
end

-- Load every frame of an exact sprite folder as a looping animation.
local function registerFrames(name, folder, options)
    options = options or {}
    local paths = sortedPngPaths(folder)
    local frames = paths and loadImages(paths) or {}
    local placeholder = false
    local source = CHAPTER_ROOT .. "/" .. folder

    if #frames == 0 then
        frames = {imageFromGrid(placeholderGrid(name))}
        placeholder = true
        source = "generated:" .. name
    end

    Assets.images[name] = newEntry(frames, options.fps, placeholder, source, options.scale)
    Assets.chapterSources[name] = source
end

-- Load a set of named animations (idle/hurt/spared/...) for one sprite.
-- The first frame of the first animation is the entry's default image.
local function registerAnimationSet(name, animations, options)
    options = options or {}
    local sets = {}
    local firstImage
    local anyReal = false
    local sourceParts = {}

    for animationName, spec in pairs(animations) do
        local paths = sortedPngPaths(spec.folder)
        local frames = paths and loadImages(paths) or {}
        if #frames == 0 then
            frames = {imageFromGrid(placeholderGrid(name))}
        else
            anyReal = true
        end
        sets[animationName] = {frames = frames, fps = spec.fps or 8}
        firstImage = firstImage or frames[1]
        sourceParts[#sourceParts + 1] = spec.folder
    end

    local entry = newEntry(
        firstImage and {firstImage} or {imageFromGrid(placeholderGrid(name))},
        options.fps,
        not anyReal,
        table.concat(sourceParts, ","),
        options.scale
    )
    entry.animations = sets
    Assets.images[name] = entry
    Assets.chapterSources[name] = entry.source
end

-- Single image (no animation) from one exact file path.
local function registerImage(name, path, options)
    options = options or {}
    local image = nil
    local placeholder = false
    local source = path

    if path and love.filesystem.getInfo(path, "file") then
        local ok, loaded = pcall(love.graphics.newImage, path)
        if ok then image = loaded end
    end
    if not image then
        image = imageFromGrid(placeholderGrid(name))
        placeholder = true
        source = "generated:" .. name
    end
    applyFilter(image, options.lockedFilter)

    Assets.images[name] = {
        image = image,
        frames = {image},
        fps = 1,
        placeholder = placeholder,
        source = source,
        scale = options.scale or 1,
        lockedFilter = options.lockedFilter,
        animations = nil,
    }
    Assets.chapterSources[name] = source
end

function Assets:load()
    self.images = {}
    self.chapterSources = {}

    -- Overworld walk cycles (4 frames each).
    registerFrames("hero_down", "spr_krisd", {fps = 7})
    registerFrames("hero_up", "spr_krisu", {fps = 7})
    registerFrames("hero_left", "spr_krisl", {fps = 7})
    registerFrames("hero_right", "spr_krisr", {fps = 7})
    registerFrames("friend", "spr_susied", {fps = 3}) -- idle bob for the NPC
    registerFrames("dummy", "spr_dummynpc")
    registerFrames("architect", "spr_darklancer", {fps = 2})

    -- Battle sprites: real battle idles, animated.
    registerFrames("hero_battle", "spr_krisb_idle", {fps = 8})
    registerFrames("friend_battle", "spr_susieb_idle", {fps = 8})
    registerFrames("ralsei", "spr_ralseib_idle", {fps = 8})

    -- Battle enemy: a proper Chapter 1 enemy with idle/hurt/spared sets.
    registerAnimationSet("enemy", {
        idle = {folder = "spr_jigsawry_idle", fps = 10},
        hurt = {folder = "spr_jigsawry_hurt", fps = 8},
        spared = {folder = "spr_jigsawry_spared", fps = 8},
    })

    registerImage("chapter_logo", "assets/chapter-1/sprites/IMAGE_LOGO_CENTER/IMAGE_LOGO_CENTER_0.png", {lockedFilter = "nearest"})
    registerImage("chapter_menu", "assets/chapter-1/sprites/IMAGE_MENU/IMAGE_MENU_0.png", {lockedFilter = "nearest"})
    registerImage("battle_background", "assets/chapter-1/sprites/bg_battleback1/bg_battleback1_0.png")
end

function Assets:setFilter(mode)
    if mode ~= "linear" and mode ~= "nearest" then return end
    currentFilter = mode
    for _, asset in pairs(self.images) do
        if asset.frames then
            for _, image in ipairs(asset.frames) do
                applyFilter(image, asset.lockedFilter)
            end
        end
        if asset.animations then
            for _, animation in pairs(asset.animations) do
                for _, image in ipairs(animation.frames) do
                    applyFilter(image, asset.lockedFilter)
                end
            end
        end
        if asset.image then
            applyFilter(asset.image, asset.lockedFilter)
        end
    end
end

function Assets:has(name)
    return self.images[name] ~= nil
end

function Assets:get(name)
    local asset = self.images[name]
    assert(asset, "Unknown asset: " .. tostring(name))
    return asset
end

function Assets:getSource(name)
    local asset = self.images[name]
    return asset and asset.source or nil
end

function Assets:getSize(name)
    local image = self:get(name).image
    return image:getWidth(), image:getHeight()
end

-- Pick the current animation frame.
--   options.animTime  - seconds into the animation (loops)
--   options.animation - named animation set (idle/hurt/spared/...)
function Assets:getFrame(asset, options)
    local frames = asset.frames
    local fps = asset.fps

    if asset.animations and options.animation then
        local animation = asset.animations[options.animation]
        if animation then
            frames = animation.frames
            fps = animation.fps
        end
    end

    if frames and #frames > 0 then
        if options.animTime and #frames > 1 then
            local index = (math.floor(options.animTime * fps) % #frames) + 1
            return frames[index]
        end
        return frames[1]
    end
    return asset.image
end

function Assets:draw(name, x, y, options)
    options = options or {}
    local asset = self:get(name)
    local image = self:getFrame(asset, options)
    local scaleX = (options.scaleX or 1) * asset.scale
    local scaleY = (options.scaleY or 1) * asset.scale
    local width = image:getWidth() * scaleX
    local height = image:getHeight() * scaleY
    local originX = options.centered and width / 2 or 0
    local originY = options.centered and height / 2 or 0

    love.graphics.setColor(1, 1, 1, options.alpha or 1)
    love.graphics.draw(
        image,
        math.floor(x + 0.5),
        math.floor(y + 0.5),
        options.rotation or 0,
        scaleX,
        scaleY,
        originX / scaleX,
        originY / scaleY
    )
end

function Assets:drawCover(name, x, y, width, height, options)
    options = options or {}
    local asset = self:get(name)
    local image = asset.image
    local imageWidth, imageHeight = image:getDimensions()
    local scale = math.max(width / imageWidth, height / imageHeight)
    local drawWidth = imageWidth * scale
    local drawHeight = imageHeight * scale
    local drawX = x + (width - drawWidth) / 2
    local drawY = y + (height - drawHeight) / 2

    love.graphics.setColor(1, 1, 1, options.alpha or 1)
    love.graphics.draw(image, drawX, drawY, 0, scale, scale)
end

return Assets
