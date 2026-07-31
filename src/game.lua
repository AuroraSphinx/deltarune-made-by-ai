local Assets = require("src.assets")
local Dialogue = require("src.dialogue")
local World = require("src.world")
local Battle = require("src.battle")

local Game = {
    virtualWidth = 320,
    virtualHeight = 240,
    state = "title",
}

local function loadFont(path, size)
    if love.filesystem.getInfo(path, "file") then
        local font = love.graphics.newFont(path, size)
        font:setFilter("nearest", "nearest")
        return font
    end

    return love.graphics.newFont(size)
end

function Game:load()
    self.canvas = love.graphics.newCanvas(self.virtualWidth, self.virtualHeight)
    self.canvas:setFilter("nearest", "nearest")

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
        self.titleLogo:setFilter("nearest", "nearest")
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

    self:resize(love.graphics.getDimensions())
end

function Game:resize(width, height)
    local scale = math.floor(math.min(width / self.virtualWidth, height / self.virtualHeight))
    self.scale = math.max(1, scale)
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

function Game:keypressed(key)
    if key == "f11" then
        love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
        return
    end

    if self.state == "title" then
        if key == "z" or key == "return" or key == "space" then
            self.state = "world"
        elseif key == "escape" then
            love.event.quit()
        end
    elseif self.state == "world" then
        if key == "escape" and not self.dialogue.active then
            self.state = "title"
        else
            self.world:keypressed(key)
        end
    elseif self.state == "battle" then
        self.battle:keypressed(key)
    end
end

function Game:drawTitle()
    love.graphics.clear(0.025, 0.02, 0.05, 1)

    love.graphics.setColor(0.24, 0.12, 0.38, 1)
    for index = 0, 11 do
        local x = 18 + index * 27
        local y = 66 + math.sin(index * 1.7) * 13
        love.graphics.rectangle("fill", x, y, 2, 2)
    end

    love.graphics.setColor(1, 1, 1, 1)
    if self.titleLogo then
        local logoX = math.floor((self.virtualWidth - self.titleLogo:getWidth()) / 2)
        love.graphics.draw(self.titleLogo, logoX, 70)
    else
        love.graphics.setFont(self.fonts.title)
        love.graphics.printf("DELTA SCRATCH", 0, 70, self.virtualWidth, "center")
    end

    love.graphics.setFont(self.fonts.subtitle)
    love.graphics.setColor(0.72, 0.58, 0.92, 1)
    love.graphics.printf("CHAPTER 1 ENGINE PROTOTYPE", 0, 111, self.virtualWidth, "center")

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Press Z or Enter", 0, 153, self.virtualWidth, "center")

    love.graphics.setFont(self.fonts.tiny)
    love.graphics.setColor(0.65, 0.65, 0.70, 1)
    love.graphics.printf("Original placeholder art only. Proprietary game assets are not included.", 28, 207, 264, "center")
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

    love.graphics.clear(0.01, 0.01, 0.015, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas, self.offsetX, self.offsetY, 0, self.scale, self.scale)
end

return Game
