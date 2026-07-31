local Assets = require("src.assets")
local Dialogue = require("src.dialogue")
local World = require("src.world")
local Battle = require("src.battle")

local Game = {
    virtualWidth = 320,
    virtualHeight = 240,
    state = "title",
    titlePage = "main",
    titleMenuIndex = 1,
    optionsIndex = 1,
}

local TITLE_ITEMS = {"START GAME", "OPTIONS", "QUIT"}
local OPTION_ROWS = {
    {id = "resolution", label = "RESOLUTION"},
    {id = "display", label = "DISPLAY MODE"},
    {id = "scaling", label = "SCALING"},
    {id = "vsync", label = "VSYNC"},
    {id = "back", label = "BACK"},
}

local function wrap(index, count)
    return ((index - 1) % count) + 1
end

local function loadFont(path, size)
    if love.filesystem.getInfo(path, "file") then
        return love.graphics.newFont(path, size)
    end
    return love.graphics.newFont(size)
end

local function drawHeart(x, y, scale)
    scale = scale or 1
    love.graphics.setColor(1, 0.12, 0.18, 1)
    love.graphics.polygon(
        "fill",
        x, y + 3 * scale,
        x - 4 * scale, y - 1 * scale,
        x - 3 * scale, y - 4 * scale,
        x, y - 2 * scale,
        x + 3 * scale, y - 4 * scale,
        x + 4 * scale, y - 1 * scale
    )
end

function Game:buildResolutionList()
    local common = {
        {640, 480},
        {800, 600},
        {960, 720},
        {1024, 768},
        {1280, 720},
        {1280, 800},
        {1366, 768},
        {1600, 900},
        {1920, 1080},
        {2560, 1440},
    }

    local desktopWidth, desktopHeight = love.window.getDesktopDimensions(1)
    local currentWidth, currentHeight = love.graphics.getDimensions()
    local seen = {}
    local resolutions = {}

    local function add(width, height)
        if not width or not height or width < 1 or height < 1 then return end
        local key = tostring(width) .. "x" .. tostring(height)
        if seen[key] then return end
        seen[key] = true
        table.insert(resolutions, {width = width, height = height})
    end

    for _, resolution in ipairs(common) do
        add(resolution[1], resolution[2])
    end
    add(currentWidth, currentHeight)
    add(desktopWidth, desktopHeight)

    table.sort(resolutions, function(a, b)
        local areaA = a.width * a.height
        local areaB = b.width * b.height
        if areaA == areaB then return a.width < b.width end
        return areaA < areaB
    end)

    self.desktopWidth = desktopWidth
    self.desktopHeight = desktopHeight
    self.resolutions = resolutions
end

function Game:findResolutionIndex(width, height)
    for index, resolution in ipairs(self.resolutions) do
        if resolution.width == width and resolution.height == height then
            return index
        end
    end

    table.insert(self.resolutions, {width = width, height = height})
    table.sort(self.resolutions, function(a, b)
        local areaA = a.width * a.height
        local areaB = b.width * b.height
        if areaA == areaB then return a.width < b.width end
        return areaA < areaB
    end)

    for index, resolution in ipairs(self.resolutions) do
        if resolution.width == width and resolution.height == height then
            return index
        end
    end
    return 1
end

function Game:loadSettings()
    local currentWidth, currentHeight = love.graphics.getDimensions()
    self.settings = {
        width = currentWidth,
        height = currentHeight,
        display = "windowed",
        scaling = "smooth",
        vsync = true,
    }

    if love.filesystem.getInfo("settings.cfg", "file") then
        local contents = love.filesystem.read("settings.cfg") or ""
        for line in contents:gmatch("[^\r\n]+") do
            local key, value = line:match("^([%w_]+)=(.+)$")
            if key == "width" then
                self.settings.width = tonumber(value) or self.settings.width
            elseif key == "height" then
                self.settings.height = tonumber(value) or self.settings.height
            elseif key == "display" and (value == "windowed" or value == "borderless") then
                self.settings.display = value
            elseif key == "scaling" and (value == "smooth" or value == "pixel") then
                self.settings.scaling = value
            elseif key == "vsync" then
                self.settings.vsync = value == "true"
            end
        end
    end

    self.resolutionIndex = self:findResolutionIndex(self.settings.width, self.settings.height)
end

function Game:saveSettings()
    local resolution = self.resolutions[self.resolutionIndex]
    self.settings.width = resolution.width
    self.settings.height = resolution.height

    local contents = table.concat({
        "width=" .. tostring(self.settings.width),
        "height=" .. tostring(self.settings.height),
        "display=" .. self.settings.display,
        "scaling=" .. self.settings.scaling,
        "vsync=" .. tostring(self.settings.vsync),
        "",
    }, "\n")

    local success, message = love.filesystem.write("settings.cfg", contents)
    if not success then
        self.settingsMessage = "Could not save settings: " .. tostring(message)
    end
end

function Game:applyRenderFilter()
    local filter = self.settings.scaling == "smooth" and "linear" or "nearest"
    love.graphics.setDefaultFilter(filter, filter, 1)
    self.canvas:setFilter(filter, filter)

    for _, font in pairs(self.fonts) do
        font:setFilter(filter, filter)
    end
    if self.titleLogo then
        self.titleLogo:setFilter(filter, filter)
    end
    if self.assets and self.assets.setFilter then
        self.assets:setFilter(filter)
    end
end

function Game:applyWindowSettings()
    local resolution = self.resolutions[self.resolutionIndex]
    local fullscreen = self.settings.display == "borderless"
    local width = fullscreen and self.desktopWidth or resolution.width
    local height = fullscreen and self.desktopHeight or resolution.height

    local success = love.window.setMode(width, height, {
        fullscreen = fullscreen,
        fullscreentype = "desktop",
        resizable = not fullscreen,
        minwidth = 640,
        minheight = 480,
        vsync = self.settings.vsync and 1 or 0,
    })

    if not success then
        self.settingsMessage = "That display mode was rejected."
        self.settings.display = "windowed"
        love.window.setMode(960, 720, {
            fullscreen = false,
            resizable = true,
            minwidth = 640,
            minheight = 480,
            vsync = self.settings.vsync and 1 or 0,
        })
        self.resolutionIndex = self:findResolutionIndex(960, 720)
    else
        self.settingsMessage = nil
    end

    self:resize(love.graphics.getDimensions())
end

function Game:applySettings()
    self:applyRenderFilter()
    self:applyWindowSettings()
    self:saveSettings()
end

function Game:load()
    self.canvas = love.graphics.newCanvas(self.virtualWidth, self.virtualHeight)

    local monoFont = "assets/fonts/DeterminationMonoWebRegular-Z5oq.ttf"
    local sansFont = "assets/fonts/DeterminationSansWebRegular-369X.ttf"

    self.fonts = {
        tiny = loadFont(monoFont, 8),
        small = loadFont(monoFont, 10),
        normal = loadFont(monoFont, 12),
        title = loadFont(sansFont, 24),
        subtitle = loadFont(sansFont, 12),
    }

    local titleLogoPath = "assets/ui/title-logo.png"
    if love.filesystem.getInfo(titleLogoPath, "file") then
        self.titleLogo = love.graphics.newImage(titleLogoPath)
    end

    Assets:load()
    self.assets = Assets
    self.dialogue = Dialogue.new(self.fonts)
    self.battle = Battle.new(self.assets, self.fonts)
    self.world = World.new(self.assets, self.dialogue, {
        fonts = self.fonts,
        startBattle = function()
            self:startBattle()
        end,
    })

    self:buildResolutionList()
    self:loadSettings()
    self:applySettings()
    self.titlePage = "main"
    self.titleMenuIndex = 1
    self.optionsIndex = 1
end

function Game:resize(width, height)
    local scale = math.min(width / self.virtualWidth, height / self.virtualHeight)
    if self.settings and self.settings.scaling == "pixel" then
        scale = math.max(1, math.floor(scale))
    end

    self.scale = scale
    self.offsetX = math.floor((width - self.virtualWidth * self.scale) / 2)
    self.offsetY = math.floor((height - self.virtualHeight * self.scale) / 2)
end

function Game:startBattle()
    self.state = "battle"
    self.battle:start(function()
        self.state = "world"
    end)
end

function Game:update(dt)
    if self.state == "world" then
        self.world:update(dt)
        self.dialogue:update(dt)
    elseif self.state == "battle" then
        self.battle:update(dt)
    end
end

function Game:changeOption(direction)
    local row = OPTION_ROWS[self.optionsIndex]
    if row.id == "resolution" then
        self.resolutionIndex = wrap(self.resolutionIndex + direction, #self.resolutions)
        self:applyWindowSettings()
    elseif row.id == "display" then
        self.settings.display = self.settings.display == "windowed" and "borderless" or "windowed"
        self:applyWindowSettings()
    elseif row.id == "scaling" then
        self.settings.scaling = self.settings.scaling == "smooth" and "pixel" or "smooth"
        self:applyRenderFilter()
        self:resize(love.graphics.getDimensions())
    elseif row.id == "vsync" then
        self.settings.vsync = not self.settings.vsync
        self:applyWindowSettings()
    end
    self:saveSettings()
end

function Game:toggleFullscreen()
    self.settings.display = self.settings.display == "windowed" and "borderless" or "windowed"
    self:applyWindowSettings()
    self:saveSettings()
end

function Game:keypressed(key)
    if key == "f11" then
        self:toggleFullscreen()
        return
    end

    if self.state == "title" then
        if self.titlePage == "main" then
            if key == "up" or key == "w" then
                self.titleMenuIndex = wrap(self.titleMenuIndex - 1, #TITLE_ITEMS)
            elseif key == "down" or key == "s" then
                self.titleMenuIndex = wrap(self.titleMenuIndex + 1, #TITLE_ITEMS)
            elseif key == "z" or key == "return" or key == "space" then
                local selected = TITLE_ITEMS[self.titleMenuIndex]
                if selected == "START GAME" then
                    self.state = "world"
                elseif selected == "OPTIONS" then
                    self.titlePage = "options"
                    self.optionsIndex = 1
                elseif selected == "QUIT" then
                    love.event.quit()
                end
            elseif key == "escape" then
                love.event.quit()
            end
        else
            if key == "up" or key == "w" then
                self.optionsIndex = wrap(self.optionsIndex - 1, #OPTION_ROWS)
            elseif key == "down" or key == "s" then
                self.optionsIndex = wrap(self.optionsIndex + 1, #OPTION_ROWS)
            elseif key == "left" or key == "a" then
                self:changeOption(-1)
            elseif key == "right" or key == "d" then
                self:changeOption(1)
            elseif key == "z" or key == "return" or key == "space" then
                if OPTION_ROWS[self.optionsIndex].id == "back" then
                    self.titlePage = "main"
                else
                    self:changeOption(1)
                end
            elseif key == "x" or key == "escape" then
                self.titlePage = "main"
            end
        end
    elseif self.state == "world" then
        if key == "escape" and not self.dialogue.active then
            self.state = "title"
            self.titlePage = "main"
        else
            self.world:keypressed(key)
        end
    elseif self.state == "battle" then
        self.battle:keypressed(key)
    end
end

function Game:drawTitleBackdrop()
    love.graphics.clear(0.018, 0.012, 0.035, 1)

    love.graphics.setColor(0.17, 0.06, 0.25, 0.7)
    for x = -20, self.virtualWidth + 20, 24 do
        love.graphics.line(x, 0, x - 34, self.virtualHeight)
    end
    love.graphics.setColor(0.29, 0.12, 0.42, 0.45)
    for y = 20, self.virtualHeight, 24 do
        love.graphics.line(0, y, self.virtualWidth, y)
    end

    love.graphics.setColor(0, 0, 0, 0.56)
    love.graphics.rectangle("fill", 20, 22, 280, 196)
    love.graphics.setColor(0.55, 0.25, 0.78, 0.65)
    love.graphics.rectangle("line", 20, 22, 280, 196)
end

function Game:drawTitleHeader(y)
    love.graphics.setColor(1, 1, 1, 1)
    if self.titleLogo then
        local logoX = math.floor((self.virtualWidth - self.titleLogo:getWidth()) / 2)
        love.graphics.draw(self.titleLogo, logoX, y)
    else
        love.graphics.setFont(self.fonts.title)
        love.graphics.printf("DELTA SCRATCH", 0, y, self.virtualWidth, "center")
    end

    love.graphics.setFont(self.fonts.tiny)
    love.graphics.setColor(0.75, 0.56, 0.92, 1)
    love.graphics.printf("CHAPTER 1 ENGINE PROTOTYPE", 0, y + 38, self.virtualWidth, "center")
end

function Game:drawMainTitleMenu()
    self:drawTitleHeader(47)

    love.graphics.setFont(self.fonts.normal)
    for index, label in ipairs(TITLE_ITEMS) do
        local y = 118 + (index - 1) * 25
        local selected = index == self.titleMenuIndex
        if selected then
            love.graphics.setColor(1, 1, 1, 1)
            drawHeart(95, y + 7, 0.7)
        else
            love.graphics.setColor(0.52, 0.47, 0.58, 1)
        end
        love.graphics.printf(label, 105, y, 120, "left")
    end

    love.graphics.setFont(self.fonts.tiny)
    love.graphics.setColor(0.62, 0.60, 0.68, 1)
    love.graphics.printf("ARROWS + Z / ENTER     F11 FULLSCREEN", 0, 205, self.virtualWidth, "center")
end

function Game:getOptionValue(row)
    if row.id == "resolution" then
        local resolution = self.resolutions[self.resolutionIndex]
        return tostring(resolution.width) .. " x " .. tostring(resolution.height)
    elseif row.id == "display" then
        return self.settings.display == "borderless" and "BORDERLESS" or "WINDOWED"
    elseif row.id == "scaling" then
        return self.settings.scaling == "smooth" and "SMOOTH" or "PIXEL PERFECT"
    elseif row.id == "vsync" then
        return self.settings.vsync and "ON" or "OFF"
    end
    return ""
end

function Game:drawOptions()
    self:drawTitleHeader(31)

    love.graphics.setFont(self.fonts.subtitle)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("OPTIONS", 0, 78, self.virtualWidth, "center")

    love.graphics.setFont(self.fonts.small)
    for index, row in ipairs(OPTION_ROWS) do
        local y = 102 + (index - 1) * 21
        local selected = index == self.optionsIndex

        if selected then
            drawHeart(35, y + 6, 0.58)
            love.graphics.setColor(1, 1, 1, 1)
        else
            love.graphics.setColor(0.55, 0.51, 0.62, 1)
        end

        love.graphics.print(row.label, 46, y)
        if row.id ~= "back" then
            local value = self:getOptionValue(row)
            if selected then
                love.graphics.setColor(0.98, 0.72, 0.30, 1)
            else
                love.graphics.setColor(0.66, 0.58, 0.72, 1)
            end
            love.graphics.printf("< " .. value .. " >", 142, y, 139, "right")
        end
    end

    love.graphics.setFont(self.fonts.tiny)
    if self.settingsMessage then
        love.graphics.setColor(1, 0.35, 0.35, 1)
        love.graphics.printf(self.settingsMessage, 26, 207, 268, "center")
    else
        love.graphics.setColor(0.64, 0.61, 0.70, 1)
        love.graphics.printf("LEFT / RIGHT TO CHANGE   X / ESC TO GO BACK", 0, 207, self.virtualWidth, "center")
    end
end

function Game:drawTitle()
    self:drawTitleBackdrop()
    if self.titlePage == "options" then
        self:drawOptions()
    else
        self:drawMainTitleMenu()
    end
end

function Game:drawVirtual()
    if self.state == "title" then
        self:drawTitle()
    elseif self.state == "world" then
        self.world:draw()
        self.dialogue:draw()
    elseif self.state == "battle" then
        self.battle:draw()
    end
end

function Game:draw()
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0, 0, 0, 1)
    self:drawVirtual()
    love.graphics.setCanvas()

    love.graphics.clear(0.008, 0.008, 0.012, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas, self.offsetX, self.offsetY, 0, self.scale, self.scale)
end

return Game
