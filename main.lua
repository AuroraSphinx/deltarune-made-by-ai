local Game = require("src.game")
local KristalErrorHandler = require("vendor.kristal_legacy.errorhandler")

love.errorhandler = KristalErrorHandler

function love.load()
    love.graphics.setDefaultFilter("linear", "linear", 1)
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
