local Util = require("src.util")

local World = {}
World.__index = World

local TILE = 16
local VIRTUAL_WIDTH = 320
local VIRTUAL_HEIGHT = 240

local function rect(x, y, w, h)
    return {x = x, y = y, w = w, h = h}
end

local rooms = {
    field = {
        spawn = {x = 42, y = 116},
        walls = {
            rect(0, 0, 320, 18),
            rect(0, 222, 320, 18),
            rect(0, 0, 18, 240),
            rect(302, 0, 18, 92),
            rect(302, 148, 18, 92),
            rect(78, 58, 52, 26),
            rect(178, 150, 62, 28),
        },
        exits = {
            {x = 304, y = 92, w = 16, h = 56, target = "hall", spawnX = 28, spawnY = 116},
        },
        npcs = {
            {
                id = "friend",
                sprite = "friend",
                name = "Purple Friend",
                x = 116,
                y = 110,
                w = 16,
                h = 24,
                lines = {
                    {speaker = "Purple Friend", text = "Okay. We built movement, collisions, dialogue, rooms, and a battle loop."},
                    {speaker = "Purple Friend", text = "The art is temporary. Drop legally obtained PNGs into the asset folders when you're ready."},
                },
            },
            {
                id = "dummy",
                sprite = "dummy",
                name = "Training Dummy",
                x = 238,
                y = 78,
                w = 16,
                h = 24,
                lines = {
                    {speaker = "Training Dummy", text = "I am an original placeholder enemy. Want to test the battle system?"},
                    {speaker = "Training Dummy", text = "Press Z again after this box closes. Prepare for extremely square bullets."},
                },
                battle = true,
            },
        },
    },
    hall = {
        spawn = {x = 28, y = 116},
        walls = {
            rect(0, 0, 320, 24),
            rect(0, 216, 320, 24),
            rect(0, 0, 14, 88),
            rect(0, 152, 14, 88),
            rect(306, 0, 14, 240),
            rect(96, 54, 18, 132),
            rect(206, 54, 18, 132),
        },
        exits = {
            {x = 0, y = 88, w = 16, h = 64, target = "field", spawnX = 286, spawnY = 116},
        },
        npcs = {
            {
                id = "architect",
                sprite = "architect",
                name = "Room Architect",
                x = 258,
                y = 108,
                w = 16,
                h = 24,
                lines = {
                    {speaker = "Room Architect", text = "Every area can be a Lua table: walls, exits, NPCs, and a custom draw function."},
                    {speaker = "Room Architect", text = "That means Chapter 1 can grow room by room instead of becoming one gigantic main.lua nightmare."},
                },
            },
        },
    },
}

-- NPC draw order is static (sorted by y, farthest first); sorting once here
-- avoids a per-frame table.sort in World:draw.
for _, room in pairs(rooms) do
    table.sort(room.npcs, function(a, b)
        return a.y < b.y
    end)
    for _, npc in ipairs(room.npcs) do
        npc.animTimer = 0
    end
end

-- ---------------------------------------------------------------------------
-- Static room backgrounds are pre-rendered once into canvases. The checker
-- floor and starfield used to redraw hundreds of rectangles (and reseed the
-- RNG) every single frame; now each room costs exactly one draw call.
-- ---------------------------------------------------------------------------

local function buildStarField(seed, count)
    love.math.setRandomSeed(seed)
    local stars = {}
    for _ = 1, count do
        stars[#stars + 1] = {
            x = love.math.random(20, 300),
            y = love.math.random(20, 215),
            size = love.math.random(1, 2),
        }
    end
    return stars
end

local STAR_FIELD = buildStarField(1337, 42)

local function drawFieldBackground()
    love.graphics.clear(0.055, 0.025, 0.11, 1)

    love.graphics.setColor(0.34, 0.18, 0.50, 1)
    for _, star in ipairs(STAR_FIELD) do
        love.graphics.rectangle("fill", star.x, star.y, star.size, star.size)
    end

    love.graphics.setColor(0.10, 0.06, 0.18, 1)
    love.graphics.rectangle("fill", 0, 150, 320, 90)

    love.graphics.setColor(0.18, 0.09, 0.28, 1)
    for x = 24, 296, 34 do
        local height = 24 + ((x * 7) % 28)
        love.graphics.polygon("fill", x - 10, 160, x, 160 - height, x + 10, 160)
    end

    love.graphics.setColor(0.24, 0.10, 0.34, 1)
    love.graphics.rectangle("fill", 18, 94, 284, 56)
    love.graphics.setColor(0.36, 0.17, 0.48, 1)
    love.graphics.rectangle("line", 18, 94, 284, 56)

    love.graphics.setColor(0.47, 0.22, 0.62, 1)
    love.graphics.rectangle("fill", 302, 92, 18, 56)
end

local function drawHallBackground()
    love.graphics.clear(0.035, 0.04, 0.09, 1)

    love.graphics.setColor(0.09, 0.12, 0.23, 1)
    love.graphics.rectangle("fill", 0, 24, 320, 192)

    for y = 30, 210, TILE do
        for x = 0, 319, TILE do
            local checker = ((x / TILE) + (y / TILE)) % 2
            if checker == 0 then
                love.graphics.setColor(0.11, 0.15, 0.29, 1)
            else
                love.graphics.setColor(0.08, 0.11, 0.22, 1)
            end
            love.graphics.rectangle("fill", x, y, TILE, TILE)
        end
    end

    love.graphics.setColor(0.28, 0.20, 0.48, 1)
    love.graphics.rectangle("fill", 96, 54, 18, 132)
    love.graphics.rectangle("fill", 206, 54, 18, 132)

    love.graphics.setColor(0.62, 0.42, 0.85, 1)
    love.graphics.rectangle("fill", 0, 88, 14, 64)
end

local backgrounds
local function ensureBackgrounds()
    if backgrounds then return end
    local function renderBackground(drawFn)
        local canvas = love.graphics.newCanvas(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
        love.graphics.setCanvas(canvas)
        drawFn()
        love.graphics.setCanvas()
        return canvas
    end
    backgrounds = {
        field = renderBackground(drawFieldBackground),
        hall = renderBackground(drawHallBackground),
    }
end

function World.new(assets, dialogue, callbacks)
    ensureBackgrounds()
    local self = setmetatable({
        assets = assets,
        dialogue = dialogue,
        callbacks = callbacks or {},
        roomName = "field",
        room = rooms.field,
        player = {
            x = rooms.field.spawn.x,
            y = rooms.field.spawn.y,
            w = 12,
            h = 18,
            speed = 72,
            runSpeed = 118,
            direction = "down",
        },
        transitionCooldown = 0,
        interactCooldown = 0,
        animTimer = 0,
        moving = false,
    }, World)
    return self
end

function World:setFilter(mode)
    for _, canvas in pairs(backgrounds) do
        canvas:setFilter(mode, mode)
    end
end

function World:getRoom()
    return self.room
end

function World:getPlayerRect(x, y)
    return {
        x = x or self.player.x,
        y = y or self.player.y,
        w = self.player.w,
        h = self.player.h,
    }
end

function World:collidesAt(x, y)
    local playerRect = self:getPlayerRect(x, y)
    for _, wall in ipairs(self.room.walls) do
        if Util.rectsOverlap(playerRect, wall) then
            return true
        end
    end
    return false
end

function World:moveAxis(dx, dy)
    local player = self.player
    if dx ~= 0 then
        local nextX = player.x + dx
        if not self:collidesAt(nextX, player.y) then
            player.x = nextX
        end
    end
    if dy ~= 0 then
        local nextY = player.y + dy
        if not self:collidesAt(player.x, nextY) then
            player.y = nextY
        end
    end
end

function World:update(dt)
    self.transitionCooldown = math.max(0, self.transitionCooldown - dt)
    self.interactCooldown = math.max(0, self.interactCooldown - dt)

    -- NPCs idle-animate even while dialogue is open.
    for _, npc in ipairs(self.room.npcs) do
        npc.animTimer = npc.animTimer + dt
    end

    if self.dialogue.active then
        return
    end

    local inputX = 0
    local inputY = 0
    if love.keyboard.isDown("left", "a") then inputX = inputX - 1 end
    if love.keyboard.isDown("right", "d") then inputX = inputX + 1 end
    if love.keyboard.isDown("up", "w") then inputY = inputY - 1 end
    if love.keyboard.isDown("down", "s") then inputY = inputY + 1 end

    self.player.moving = false
    if inputX ~= 0 or inputY ~= 0 then
        self.player.moving = true
        inputX, inputY = Util.normalize(inputX, inputY)
        if math.abs(inputX) > math.abs(inputY) then
            self.player.direction = inputX < 0 and "left" or "right"
        else
            self.player.direction = inputY < 0 and "up" or "down"
        end

        local speed = love.keyboard.isDown("lshift", "rshift") and self.player.runSpeed or self.player.speed
        self:moveAxis(inputX * speed * dt, inputY * speed * dt)
    end

    -- Walk cycle advances only while moving; standing shows frame 0.
    if self.player.moving then
        self.player.animTimer = self.player.animTimer + dt
    else
        self.player.animTimer = 0
    end

    if self.transitionCooldown <= 0 then
        local playerRect = self:getPlayerRect()
        for _, exit in ipairs(self.room.exits) do
            if Util.rectsOverlap(playerRect, exit) then
                local target = rooms[exit.target]
                self.roomName = exit.target
                self.room = target
                self.player.x = exit.spawnX
                self.player.y = exit.spawnY
                self.transitionCooldown = 0.3
                break
            end
        end
    end
end

function World:getInteractionPoint()
    local centerX = self.player.x + self.player.w / 2
    local centerY = self.player.y + self.player.h / 2
    local reach = 20

    if self.player.direction == "left" then centerX = centerX - reach end
    if self.player.direction == "right" then centerX = centerX + reach end
    if self.player.direction == "up" then centerY = centerY - reach end
    if self.player.direction == "down" then centerY = centerY + reach end

    return centerX, centerY
end

function World:interact()
    if self.dialogue.active or self.interactCooldown > 0 then
        return
    end

    local interactionX, interactionY = self:getInteractionPoint()
    local closest
    local closestDistance = 26 * 26

    for _, npc in ipairs(self.room.npcs) do
        local npcX = npc.x + npc.w / 2
        local npcY = npc.y + npc.h / 2
        local distance = Util.distanceSquared(interactionX, interactionY, npcX, npcY)
        if distance < closestDistance then
            closestDistance = distance
            closest = npc
        end
    end

    if closest then
        local onFinish
        if closest.battle and self.callbacks.startBattle then
            onFinish = function()
                self.interactCooldown = 0.25
                self.callbacks.startBattle()
            end
        end
        self.dialogue:start(closest.lines, onFinish)
    end
end

function World:keypressed(key)
    if self.dialogue.active then
        self.dialogue:keypressed(key)
        return
    end

    if key == "z" or key == "return" or key == "space" then
        self:interact()
    elseif key == "b" and self.callbacks.startBattle then
        self.callbacks.startBattle()
    end
end

function World:drawCollisionDebug()
    if not love.keyboard.isDown("f3") then
        return
    end

    love.graphics.setColor(1, 0.2, 0.2, 0.45)
    for _, wall in ipairs(self.room.walls) do
        love.graphics.rectangle("fill", wall.x, wall.y, wall.w, wall.h)
    end

    love.graphics.setColor(0.2, 1, 0.2, 0.65)
    for _, exit in ipairs(self.room.exits) do
        love.graphics.rectangle("fill", exit.x, exit.y, exit.w, exit.h)
    end
end

-- Draw a sprite centered on its hitbox with its feet on the hitbox bottom.
local function drawSpriteOn(assets, name, box, animTime)
    local spriteWidth, spriteHeight = assets:getSize(name)
    assets:draw(name,
        box.x + box.w / 2,
        box.y + box.h - spriteHeight / 2,
        {centered = true, animTime = animTime}
    )
end

function World:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(backgrounds[self.roomName], 0, 0)

    for _, npc in ipairs(self.room.npcs) do
        drawSpriteOn(self.assets, npc.sprite, npc, npc.animTimer)
    end

    drawSpriteOn(self.assets, "hero_" .. self.player.direction, self.player, self.player.animTimer)
    self:drawCollisionDebug()

    love.graphics.setColor(1, 1, 1, 0.75)
    love.graphics.setFont(self.callbacks.fonts.small)
    love.graphics.print(self.roomName == "field" and "ORIGINAL DARK FIELD" or "ORIGINAL TEST HALL", 8, 6)
    love.graphics.print("Z interact  |  Shift run  |  B battle  |  F3 collisions", 8, 226)
end

return World
