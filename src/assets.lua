local PlaceholderData = require("assets.placeholders")

local Assets = {
    images = {},
}

local currentFilter = "linear"

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

local function applyFilter(image)
    image:setFilter(currentFilter, currentFilter)
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

local function loadOptional(path, fallbackKey)
    if love.filesystem.getInfo(path, "file") then
        local image = love.graphics.newImage(path)
        applyFilter(image)
        return image, false
    end
    return imageFromGrid(PlaceholderData[fallbackKey]), true
end

function Assets:load()
    local imageSpecs = {
        hero_down = {"assets/characters/kris/idle_down.png", "hero_down"},
        hero_up = {"assets/characters/kris/idle_up.png", "hero_up"},
        hero_left = {"assets/characters/kris/idle_left.png", "hero_left"},
        hero_right = {"assets/characters/kris/idle_right.png", "hero_right"},
        friend = {"assets/characters/susie/idle_down.png", "friend"},
        dummy = {"assets/npcs/training_dummy.png", "dummy"},
        enemy = {"assets/enemies/training_dummy.png", "enemy"},
    }

    for name, spec in pairs(imageSpecs) do
        local image, placeholder = loadOptional(spec[1], spec[2])
        self.images[name] = {
            image = image,
            placeholder = placeholder,
            scale = placeholder and 2 or 1,
        }
    end
end

function Assets:setFilter(mode)
    if mode ~= "linear" and mode ~= "nearest" then return end
    currentFilter = mode
    for _, asset in pairs(self.images) do
        applyFilter(asset.image)
    end
end

function Assets:get(name)
    local asset = self.images[name]
    assert(asset, "Unknown asset: " .. tostring(name))
    return asset
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

return Assets
