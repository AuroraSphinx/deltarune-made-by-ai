local PlaceholderData = require("assets.placeholders")

local Assets = {
    images = {},
    chapterSources = {},
}

local currentFilter = "nearest"
local CHAPTER_ROOT = "assets/chapter-1/sprites"
local chapterFiles = nil

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

local function walkPngFiles(root, output)
    local info = love.filesystem.getInfo(root)
    if not info or info.type ~= "directory" then return end

    for _, name in ipairs(love.filesystem.getDirectoryItems(root)) do
        local path = root .. "/" .. name
        local child = love.filesystem.getInfo(path)
        if child and child.type == "directory" then
            walkPngFiles(path, output)
        elseif child and child.type == "file" and path:lower():sub(-4) == ".png" then
            output[#output + 1] = path
        end
    end
end

local function buildChapterIndex()
    if chapterFiles then return chapterFiles end
    chapterFiles = {}
    walkPngFiles(CHAPTER_ROOT, chapterFiles)
    table.sort(chapterFiles)
    return chapterFiles
end

local function isRejected(path, rejected)
    local lower = path:lower()
    for _, token in ipairs(rejected or {}) do
        if lower:find(token, 1, true) then return true end
    end
    return false
end

local function findChapterFile(patterns, rejected)
    local files = buildChapterIndex()
    local bestPath = nil
    local bestScore = -math.huge

    for _, path in ipairs(files) do
        local lower = path:lower()
        if not isRejected(lower, rejected) then
            for rank, pattern in ipairs(patterns) do
                if lower:find(pattern, 1, true) then
                    local score = 10000 - rank * 100
                    if lower:match("_0%.png$") then score = score + 80 end
                    if lower:find("/battle", 1, true) then score = score + 25 end
                    score = score - #lower * 0.01
                    if score > bestScore then
                        bestScore = score
                        bestPath = path
                    end
                    break
                end
            end
        end
    end

    return bestPath
end

local function firstExisting(paths)
    for _, path in ipairs(paths or {}) do
        if path and love.filesystem.getInfo(path, "file") then
            return path
        end
    end
    return nil
end

local function safeNewImage(path, forcedFilter)
    if not path then return nil end
    local ok, image = pcall(love.graphics.newImage, path)
    if not ok then return nil end
    applyFilter(image, forcedFilter)
    return image
end

local function registerImage(name, paths, fallbackKey, options)
    options = options or {}
    local selected = firstExisting(paths)
    local image = safeNewImage(selected, options.lockedFilter)
    local placeholder = false

    if not image and fallbackKey then
        image = imageFromGrid(PlaceholderData[fallbackKey])
        placeholder = true
        selected = "generated:" .. fallbackKey
    end

    if not image then return false end

    Assets.images[name] = {
        image = image,
        placeholder = placeholder,
        source = selected,
        scale = options.scale or (placeholder and 2 or 1),
        lockedFilter = options.lockedFilter,
    }
    Assets.chapterSources[name] = selected
    return true
end

local function chapterPath(patterns, rejected)
    return findChapterFile(patterns, rejected)
end

function Assets:load()
    self.images = {}
    self.chapterSources = {}
    buildChapterIndex()

    local rejectPortraits = {
        "face", "head", "portrait", "talk", "hurt", "attack", "slash",
        "menu", "button", "icon", "dark", "lightworld", "cutscene",
    }

    local heroDown = chapterPath({
        "spr_kris_dw", "spr_kris_down", "kris_dw", "kris_down",
    }, rejectPortraits)
    local heroUp = chapterPath({
        "spr_kris_up", "kris_up",
    }, rejectPortraits)
    local heroLeft = chapterPath({
        "spr_kris_l", "spr_kris_left", "kris_left", "kris_l_",
    }, rejectPortraits)
    local heroRight = chapterPath({
        "spr_kris_r", "spr_kris_right", "kris_right", "kris_r_",
    }, rejectPortraits)

    local susie = chapterPath({
        "spr_susie_dw", "spr_susie_down", "susie_dw", "susie_down",
        "spr_susie_walk", "spr_susie",
    }, rejectPortraits)

    local ralsei = chapterPath({
        "spr_ralsei_dw", "spr_ralsei_down", "ralsei_dw", "ralsei_down",
        "spr_ralsei_walk", "spr_ralsei",
    }, rejectPortraits)

    local rudinnBattle = chapterPath({
        "spr_rudinn_battle", "rudinn_battle", "spr_rudinn", "rudinn",
    }, {"bullet", "diamond", "hurt", "spare", "face", "icon"})

    registerImage("hero_down", {
        heroDown,
        "assets/characters/kris/idle_down.png",
    }, "hero_down")
    registerImage("hero_up", {
        heroUp,
        heroDown,
        "assets/characters/kris/idle_up.png",
    }, "hero_up")
    registerImage("hero_left", {
        heroLeft,
        heroDown,
        "assets/characters/kris/idle_left.png",
    }, "hero_left")
    registerImage("hero_right", {
        heroRight,
        heroLeft,
        heroDown,
        "assets/characters/kris/idle_right.png",
    }, "hero_right")
    registerImage("friend", {
        susie,
        "assets/characters/susie/idle_down.png",
    }, "friend")
    registerImage("ralsei", {ralsei}, nil)
    registerImage("dummy", {
        rudinnBattle,
        "assets/npcs/training_dummy.png",
    }, "dummy")
    registerImage("enemy", {
        rudinnBattle,
        "assets/enemies/training_dummy.png",
    }, "enemy")

    registerImage("chapter_logo", {
        "assets/chapter-1/sprites/IMAGE_LOGO_CENTER/IMAGE_LOGO_CENTER_0.png",
        "assets/chapter-1/sprites/IMAGE_LOGO/IMAGE_LOGO_0.png",
    }, nil, {lockedFilter = "nearest"})

    registerImage("chapter_menu", {
        "assets/chapter-1/sprites/IMAGE_MENU/IMAGE_MENU_0.png",
    }, nil, {lockedFilter = "nearest"})

    registerImage("battle_background", {
        "assets/chapter-1/sprites/bg_battleback1/bg_battleback1_0.png",
    }, nil)
end

function Assets:setFilter(mode)
    if mode ~= "linear" and mode ~= "nearest" then return end
    currentFilter = mode
    for _, asset in pairs(self.images) do
        applyFilter(asset.image, asset.lockedFilter)
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

function Assets:draw(name, x, y, options)
    options = options or {}
    local asset = self:get(name)
    local scaleX = (options.scaleX or 1) * asset.scale
    local scaleY = (options.scaleY or 1) * asset.scale
    local width = asset.image:getWidth() * scaleX
    local height = asset.image:getHeight() * scaleY
    local originX = options.centered and width / 2 or 0
    local originY = options.centered and height / 2 or 0

    love.graphics.setColor(1, 1, 1, options.alpha or 1)
    love.graphics.draw(
        asset.image,
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
