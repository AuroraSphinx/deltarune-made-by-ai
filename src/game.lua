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
    {id = "scaling", label = "WORLD FILTER"},
    {id = "vsync", label = "VSYNC"},
    {id = "back", label = "BACK"},
}
local SCALING_MODES = {"smooth", "sharp", "pixel"}

local function wrap(index, count)
    return ((index - 1) % count) + 1
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function loadFont(path, size, filter)
    local font
    if love.filesystem.getInfo(path, "file") then
        font = love.graphics.newFont(path, size)
    else
        font = love.graphics.newFont(size)
    end
    if filter then
        font:setFilter(filter, filter)
    end
    return font
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
        scaling = "sharp",
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
            elseif key == "scaling" and (value == "smooth" or value == "sharp" or value == "pixel") then
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

function Game:rebuildNativeFonts(width, height)
    if not self.monoFontPath or not self.sansFontPath then return end

    local uiScale = clamp(height / 720, 0.75, 2.25)
    local function scaled(size)
        return math.max(8, math.floor(size * uiScale + 0.5))
    end

    self.nativeScale = uiScale
    self.nativeFonts = {
        tiny = loadFont(self.monoFontPath, scaled(14), "linear"),
        small = loadFont(self.monoFontPath, scaled(20), "linear"),
        normal = loadFont(self.monoFontPath, scaled(26), "linear"),
        subtitle = loadFont(self.sansFontPath, scaled(22), "linear"),
        title = loadFont(self.sansFontPath, scaled(66), "linear"),
    }
end

function Game:applyRenderFilter()
    local filter = self.settings.scaling == "smooth" and "linear" or "nearest"
    love.graphics.setDefaultFilter(filter, filter, 1)
    self.canvas:setFilter(filter, filter)

    for _, font in pairs(self.fonts) do
        font:setFilter(filter, filter)
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

    self.monoFontPath = "assets/fonts/DeterminationMonoWebRegular-Z5oq.ttf"
    self.sansFontPath = "assets/fonts/DeterminationSansWebRegular-369X.ttf"

    self.fonts = {
        tiny = loadFont(self.monoFontPath, 8),
        small = loadFont(self.monoFontPath, 10),
        normal = loadFont(self.monoFontPath, 12),
        title = loadFont(self.sansFontPath, 24),
        subtitle = loadFont(self.sansFontPath, 12),
    }

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
    self:rebuildNativeFonts(width, height)
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
        local current = 1
        for index, mode in ipairs(SCALING_MODES) do
            if mode == self.settings.scaling then
                current = index
                break
            end
        end
        self.settings.scaling = SCALING_MODES[wrap(current + direction, #SCALING_MODES)]
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

function Game:getNativePanel(width, height)
    local margin = math.max(24, math.floor(40 * self.nativeScale))
    local panelWidth = math.min(width - margin * 2, math.floor(900 * self.nativeScale))
    local panelHeight = math.min(height - margin * 2, math.floor(610 * self.nativeScale))
    local panelX = math.floor((width - panelWidth) / 2)
    local panelY = math.floor((height - panelHeight) / 2)
    return panelX, panelY, panelWidth, panelHeight
end

function Game:drawNativeBackdrop(width, height)
    love.graphics.clear(0.018, 0.012, 0.035, 1)

    local spacing = math.max(48, math.floor(72 * self.nativeScale))
    love.graphics.setLineWidth(math.max(1, self.nativeScale))
    love.graphics.setColor(0.18, 0.055, 0.28, 0.75)
    for x = -height, width + height, spacing do
        love.graphics.line(x, 0, x - math.floor(height * 0.20), height)
    end

    love.graphics.setColor(0.30, 0.11, 0.45, 0.42)
    for y = spacing, height, spacing do
        love.graphics.line(0, y, width, y)
    end

    local panelX, panelY, panelWidth, panelHeight = self:getNativePanel(width, height)
    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight)
    love.graphics.setColor(0.49, 0.21, 0.72, 0.88)
    love.graphics.setLineWidth(math.max(2, math.floor(3 * self.nativeScale)))
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight)

    return panelX, panelY, panelWidth, panelHeight
end

function Game:drawNativeTitleHeader(panelX, panelY, panelWidth, compact)
    local titleY = panelY + math.floor((compact and 24 or 42) * self.nativeScale)

    love.graphics.setFont(self.nativeFonts.title)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("DELTA SCRATCH", panelX, titleY, panelWidth, "center")

    love.graphics.setFont(self.nativeFonts.tiny)
    love.graphics.setColor(0.76, 0.57, 0.94, 1)
    local subtitleY = titleY + self.nativeFonts.title:getHeight() + math.floor(4 * self.nativeScale)
    love.graphics.printf("CHAPTER 1 ENGINE PROTOTYPE", panelX, subtitleY, panelWidth, "center")

    return subtitleY + self.nativeFonts.tiny:getHeight()
end

function Game:drawMainTitleMenuNative(panelX, panelY, panelWidth, panelHeight)
    local headerBottom = self:drawNativeTitleHeader(panelX, panelY, panelWidth, false)
    local menuTop = math.max(
        headerBottom + math.floor(40 * self.nativeScale),
        panelY + math.floor(panelHeight * 0.48)
    )
    local rowGap = math.floor(58 * self.nativeScale)
    local textWidth = math.min(panelWidth, math.floor(360 * self.nativeScale))
    local textX = math.floor(panelX + (panelWidth - textWidth) / 2)

    love.graphics.setFont(self.nativeFonts.normal)
    for index, label in ipairs(TITLE_ITEMS) do
        local y = menuTop + (index - 1) * rowGap
        local selected = index == self.titleMenuIndex
        if selected then
            love.graphics.setColor(1, 1, 1, 1)
            drawHeart(textX - math.floor(26 * self.nativeScale), y + self.nativeFonts.normal:getHeight() * 0.48, 1.45 * self.nativeScale)
        else
            love.graphics.setColor(0.50, 0.46, 0.57, 1)
        end
        love.graphics.printf(label, textX, y, textWidth, "center")
    end

    love.graphics.setFont(self.nativeFonts.tiny)
    love.graphics.setColor(0.64, 0.62, 0.70, 1)
    love.graphics.printf(
        "ARROWS + Z / ENTER     F11 FULLSCREEN",
        panelX,
        panelY + panelHeight - self.nativeFonts.tiny:getHeight() - math.floor(18 * self.nativeScale),
        panelWidth,
        "center"
    )
end

function Game:getOptionValue(row)
    if row.id == "resolution" then
        local resolution = self.resolutions[self.resolutionIndex]
        return tostring(resolution.width) .. " x " .. tostring(resolution.height)
    elseif row.id == "display" then
        return self.settings.display == "borderless" and "BORDERLESS" or "WINDOWED"
    elseif row.id == "scaling" then
        if self.settings.scaling == "smooth" then return "SMOOTH" end
        if self.settings.scaling == "sharp" then return "SHARP" end
        return "PIXEL PERFECT"
    elseif row.id == "vsync" then
        return self.settings.vsync and "ON" or "OFF"
    end
    return ""
end

function Game:drawOptionsNative(panelX, panelY, panelWidth, panelHeight)
    local headerBottom = self:drawNativeTitleHeader(panelX, panelY, panelWidth, true)

    love.graphics.setFont(self.nativeFonts.subtitle)
    love.graphics.setColor(1, 1, 1, 1)
    local optionsY = headerBottom + math.floor(14 * self.nativeScale)
    love.graphics.printf("OPTIONS", panelX, optionsY, panelWidth, "center")

    local rowsTop = optionsY + self.nativeFonts.subtitle:getHeight() + math.floor(34 * self.nativeScale)
    local rowGap = math.floor(58 * self.nativeScale)
    local leftX = panelX + math.floor(78 * self.nativeScale)
    local rightX = panelX + math.floor(panelWidth * 0.53)
    local rightWidth = panelX + panelWidth - rightX - math.floor(78 * self.nativeScale)

    love.graphics.setFont(self.nativeFonts.small)
    for index, row in ipairs(OPTION_ROWS) do
        local y = rowsTop + (index - 1) * rowGap
        local selected = index == self.optionsIndex

        if selected then
            drawHeart(leftX - math.floor(28 * self.nativeScale), y + self.nativeFonts.small:getHeight() * 0.48, 1.25 * self.nativeScale)
            love.graphics.setColor(1, 1, 1, 1)
        else
            love.graphics.setColor(0.56, 0.52, 0.63, 1)
        end

        love.graphics.print(row.label, leftX, y)
        if row.id ~= "back" then
            if selected then
                love.graphics.setColor(1.00, 0.73, 0.28, 1)
            else
                love.graphics.setColor(0.67, 0.59, 0.73, 1)
            end
            love.graphics.printf("<  " .. self:getOptionValue(row) .. "  >", rightX, y, rightWidth, "right")
        end
    end

    love.graphics.setFont(self.nativeFonts.tiny)
    local footerY = panelY + panelHeight - self.nativeFonts.tiny:getHeight() - math.floor(18 * self.nativeScale)
    if self.settingsMessage then
        love.graphics.setColor(1, 0.35, 0.35, 1)
        love.graphics.printf(self.settingsMessage, panelX + 20, footerY, panelWidth - 40, "center")
    else
        love.graphics.setColor(0.66, 0.63, 0.72, 1)
        love.graphics.printf(
            "LEFT / RIGHT TO CHANGE   X / ESC TO GO BACK   TITLE UI IS NATIVE RESOLUTION",
            panelX + 20,
            footerY,
            panelWidth - 40,
            "center"
        )
    end
end

function Game:drawTitleNative()
    local width, height = love.graphics.getDimensions()
    if not self.nativeFonts then
        self:rebuildNativeFonts(width, height)
    end

    local panelX, panelY, panelWidth, panelHeight = self:drawNativeBackdrop(width, height)
    if self.titlePage == "options" then
        self:drawOptionsNative(panelX, panelY, panelWidth, panelHeight)
    else
        self:drawMainTitleMenuNative(panelX, panelY, panelWidth, panelHeight)
    end
end

function Game:drawVirtual()
    if self.state == "world" then
        self.world:draw()
        self.dialogue:draw()
    elseif self.state == "battle" then
        self.battle:draw()
    end
end

function Game:draw()
    if self.state == "title" then
        love.graphics.setCanvas()
        self:drawTitleNative()
        return
    end

    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0, 0, 0, 1)
    self:drawVirtual()
    love.graphics.setCanvas()

    love.graphics.clear(0.008, 0.008, 0.012, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas, self.offsetX, self.offsetY, 0, self.scale, self.scale)
end

return Game
