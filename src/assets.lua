local PlaceholderData = require("assets.placeholders")

local Assets = {
    roots = {
        sprites = "assets/sprites",
        sounds = "assets/sounds",
        music = "assets/music",
        fonts = "assets/fonts",
        shaders = "assets/shaders",
    },
}

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

local DEFAULT_ALIASES = {
    hero_down = "party/kris/dark/walk/down",
    hero_up = "party/kris/dark/walk/up",
    hero_left = "party/kris/dark/walk/left",
    hero_right = "party/kris/dark/walk/right",
    friend = "party/susie/dark/walk/down",
    dummy = "world/npcs/training_dummy",
    enemy = "enemies/training_dummy",
}

local DEFAULT_FALLBACKS = {
    ["party/kris/dark/walk/down"] = {grid = "hero_down", scale = 2},
    ["party/kris/dark/walk/up"] = {grid = "hero_up", scale = 2},
    ["party/kris/dark/walk/left"] = {grid = "hero_left", scale = 2},
    ["party/kris/dark/walk/right"] = {grid = "hero_right", scale = 2},
    ["party/susie/dark/walk/down"] = {grid = "friend", scale = 2},
    ["world/npcs/training_dummy"] = {grid = "dummy", scale = 2},
    ["enemies/training_dummy"] = {grid = "enemy", scale = 2},
}

local function normalize(path)
    return tostring(path or "")
        :gsub("\\", "/")
        :gsub("^/+", "")
        :gsub("/+$", "")
end

local function extension(path)
    local ext = path:match("%.([^%./]+)$")
    return ext and ext:lower() or nil
end

local function stripExtension(path)
    return (path:gsub("%.[^%./]+$", ""))
end

local function relativeTo(path, root)
    path = normalize(path)
    root = normalize(root)
    if path:sub(1, #root) == root then
        return path:sub(#root + 2)
    end
    return path
end

local function walk(directory, callback)
    local info = love.filesystem.getInfo(directory)
    if not info or info.type ~= "directory" then
        return
    end

    for _, name in ipairs(love.filesystem.getDirectoryItems(directory)) do
        local path = directory .. "/" .. name
        local childInfo = love.filesystem.getInfo(path)
        if childInfo and childInfo.type == "directory" then
            walk(path, callback)
        elseif childInfo and childInfo.type == "file" then
            callback(path)
        end
    end
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
    image:setFilter("nearest", "nearest")
    return image
end

local function loadImage(path)
    local image = love.graphics.newImage(path)
    image:setFilter("nearest", "nearest")
    return image
end

function Assets:clear()
    self.loaded = false
    self.textures = {}
    self.textureIds = setmetatable({}, {__mode = "k"})
    self.frames = {}
    self.frameIds = {}
    self.frameBuckets = {}
    self.soundPaths = {}
    self.musicPaths = {}
    self.fontPaths = {}
    self.shaderPaths = {}
    self.sounds = {}
    self.fonts = {}
    self.shaders = {}
    self.placeholderImages = {}
    self.placeholderScales = {}
    self.aliases = {}
    self.fallbacks = {}

    for alias, target in pairs(DEFAULT_ALIASES) do
        self.aliases[alias] = target
    end
    for id, spec in pairs(DEFAULT_FALLBACKS) do
        self.fallbacks[id] = spec
    end
end

function Assets:registerAlias(alias, target)
    self.aliases[normalize(alias)] = normalize(target)
end

function Assets:registerFallback(id, placeholderGrid, scale)
    self.fallbacks[normalize(id)] = {
        grid = placeholderGrid,
        scale = scale or 1,
    }
end

function Assets:resolve(id)
    local current = normalize(id)
    local visited = {}

    while self.aliases[current] do
        if visited[current] then
            error("Asset alias loop at: " .. current)
        end
        visited[current] = true
        current = normalize(self.aliases[current])
    end

    return current
end

function Assets:_loadSprites()
    walk(self.roots.sprites, function(path)
        if extension(path) ~= "png" then
            return
        end

        local relative = relativeTo(path, self.roots.sprites)
        local id = stripExtension(relative)
        local frameBase, frameNumber = id:match("^(.-)_(%d+)$")
        local image = loadImage(path)

        if frameBase and frameNumber then
            self.frameBuckets[frameBase] = self.frameBuckets[frameBase] or {}
            table.insert(self.frameBuckets[frameBase], {
                index = tonumber(frameNumber),
                id = id,
                image = image,
            })
        else
            self.textures[id] = image
            self.textureIds[image] = id
        end
    end)

    for id, bucket in pairs(self.frameBuckets) do
        table.sort(bucket, function(a, b)
            return a.index < b.index
        end)

        self.frames[id] = {}
        self.frameIds[id] = {}
        for index, entry in ipairs(bucket) do
            self.frames[id][index] = entry.image
            self.frameIds[id][index] = entry.id
            self.textureIds[entry.image] = entry.id
        end
    end

    self.frameBuckets = nil
end

function Assets:_indexFiles(root, destination, acceptedExtensions)
    walk(root, function(path)
        local ext = extension(path)
        if acceptedExtensions[ext] then
            local id = stripExtension(relativeTo(path, root))
            destination[id] = path
        end
    end)
end

function Assets:load()
    self:clear()
    self:_loadSprites()
    self:_indexFiles(self.roots.sounds, self.soundPaths, {wav = true, ogg = true, mp3 = true})
    self:_indexFiles(self.roots.music, self.musicPaths, {wav = true, ogg = true, mp3 = true})
    self:_indexFiles(self.roots.fonts, self.fontPaths, {ttf = true, otf = true, fnt = true})
    self:_indexFiles(self.roots.shaders, self.shaderPaths, {glsl = true, frag = true, vert = true})
    self.loaded = true
end

function Assets:reload()
    self:load()
end

function Assets:_getPlaceholder(id)
    local spec = self.fallbacks[id]
    if not spec then
        return nil, 1
    end

    if not self.placeholderImages[id] then
        local rows = PlaceholderData[spec.grid]
        assert(rows, "Unknown placeholder grid: " .. tostring(spec.grid))
        self.placeholderImages[id] = imageFromGrid(rows)
        self.placeholderScales[id] = spec.scale or 1
    end

    return self.placeholderImages[id], self.placeholderScales[id]
end

function Assets:getTexture(id)
    id = self:resolve(id)
    if self.textures[id] then
        return self.textures[id]
    end

    local image = self:_getPlaceholder(id)
    return image
end

function Assets:getTextureID(texture)
    if type(texture) == "string" then
        return self:resolve(texture)
    end
    return self.textureIds[texture]
end

function Assets:getFrames(id)
    return self.frames[self:resolve(id)]
end

function Assets:getFrameIds(id)
    return self.frameIds[self:resolve(id)]
end

function Assets:getFramesOrTexture(id)
    id = self:resolve(id)
    if self.textures[id] then
        return {self.textures[id]}
    end
    if self.frames[id] then
        return self.frames[id]
    end

    local placeholder = self:_getPlaceholder(id)
    return placeholder and {placeholder} or nil
end

function Assets:exists(id)
    id = self:resolve(id)
    return self.textures[id] ~= nil
        or self.frames[id] ~= nil
        or self.fallbacks[id] ~= nil
end

function Assets:get(id)
    id = self:resolve(id)
    local image = self.textures[id]
    if not image and self.frames[id] then
        image = self.frames[id][1]
    end

    local placeholder = false
    local scale = 1
    if not image then
        image, scale = self:_getPlaceholder(id)
        placeholder = image ~= nil
    end

    assert(image, "Unknown sprite asset: " .. tostring(id))
    return {
        id = id,
        image = image,
        placeholder = placeholder,
        scale = scale,
    }
end

function Assets:draw(id, x, y, options)
    options = options or {}
    id = self:resolve(id)

    local image
    local scale = 1
    local frames = self.frames[id]
    if frames and #frames > 0 then
        local frame = options.frame
        if not frame then
            local time = options.time or love.timer.getTime()
            local fps = options.fps or 8
            frame = math.floor(time * fps) + 1
        end
        image = frames[((frame - 1) % #frames) + 1]
    else
        image = self.textures[id]
    end

    if not image then
        image, scale = self:_getPlaceholder(id)
    end
    assert(image, "Unknown sprite asset: " .. tostring(id))

    local scaleX = (options.scaleX or options.scale or 1) * scale
    local scaleY = (options.scaleY or options.scale or 1) * scale
    local originX = options.originX or 0
    local originY = options.originY or 0

    if options.centered then
        originX = image:getWidth() / 2
        originY = image:getHeight() / 2
    end

    love.graphics.draw(
        image,
        math.floor(x + 0.5),
        math.floor(y + 0.5),
        options.rotation or 0,
        scaleX,
        scaleY,
        originX,
        originY
    )
end

function Assets:getSound(id)
    id = normalize(id)
    if not self.soundPaths[id] then
        return nil
    end
    if not self.sounds[id] then
        self.sounds[id] = love.audio.newSource(self.soundPaths[id], "static")
    end
    return self.sounds[id]
end

function Assets:playSound(id, volume, pitch)
    local source = self:getSound(id)
    if not source then
        return nil
    end

    local instance = source:clone()
    if volume then instance:setVolume(volume) end
    if pitch then instance:setPitch(pitch) end
    instance:play()
    return instance
end

function Assets:getMusicPath(id)
    return self.musicPaths[normalize(id)]
end

function Assets:newMusic(id, looped)
    local path = self:getMusicPath(id)
    if not path then
        return nil
    end

    local source = love.audio.newSource(path, "stream")
    source:setLooping(looped ~= false)
    return source
end

function Assets:getFont(id, size)
    id = normalize(id)
    local path = self.fontPaths[id]
    if not path then
        return nil
    end

    size = size or 12
    self.fonts[id] = self.fonts[id] or {}
    if not self.fonts[id][size] then
        if extension(path) == "fnt" then
            self.fonts[id][size] = love.graphics.newFont(path)
        else
            self.fonts[id][size] = love.graphics.newFont(path, size)
        end
    end
    return self.fonts[id][size]
end

function Assets:getShader(id)
    id = normalize(id)
    local path = self.shaderPaths[id]
    if not path then
        return nil
    end

    if not self.shaders[id] then
        self.shaders[id] = love.graphics.newShader(path)
    end
    return self.shaders[id]
end

Assets:clear()

return Assets
