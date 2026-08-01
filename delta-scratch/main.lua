local Game = require("src.game")
local KristalErrorHandler = require("vendor.kristal_legacy.errorhandler")
local Chapter1Integration = require("src.chapter1_integration")

Chapter1Integration.apply(Game)
love.errorhandler = KristalErrorHandler

function love.load()
    -- "sharp" is the default scaling mode; linear here would blur the
    -- pre-resize startup frame.
    love.graphics.setDefaultFilter("nearest", "nearest", 1)
    love.keyboard.setKeyRepeat(false)
    Game:load()
end

function love.update(dt)
    Game:update(math.min(dt, 1 / 20))
end

function love.draw()
    Game:draw()
end

function love.keypressed(key, scancode, isrepeat)
    if isrepeat then
        return
    end
    Game:keypressed(key, scancode)
end

function love.resize(width, height)
    Game:resize(width, height)
end
