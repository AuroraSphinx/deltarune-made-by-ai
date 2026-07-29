local Util = require("src.util")

local Battle = {}
Battle.__index = Battle

local BOX = {x = 82, y = 104, w = 156, h = 78}
local MENU = {"FIGHT", "ACT", "SPARE", "FLEE"}

function Battle.new(assets, fonts)
    return setmetatable({
        assets = assets,
        fonts = fonts,
        active = false,
        phase = "menu",
        menuIndex = 1,
        enemy = nil,
        soul = nil,
        bullets = {},
        attackCursor = 0,
        attackDirection = 1,
        enemyTimer = 0,
        spawnTimer = 0,
        message = "",
        messageTimer = 0,
        onExit = nil,
    }, Battle)
end

function Battle:start(onExit)
    self.active = true
    self.phase = "menu"
    self.menuIndex = 1
    self.enemy = {
        name = "TRAINING SHAPE",
        hp = 72,
        maxHp = 72,
        mercy = 0,
    }
    self.soul = {
        x = BOX.x + BOX.w / 2 - 3,
        y = BOX.y + BOX.h / 2 - 3,
        w = 6,
        h = 6,
        hp = 90,
        maxHp = 90,
        invulnerability = 0,
    }
    self.bullets = {}
    self.attackCursor = 0
    self.attackDirection = 1
    self.enemyTimer = 0
    self.spawnTimer = 0
    self.message = "A suspiciously geometric opponent blocks the path."
    self.messageTimer = 1.2
    self.onExit = onExit
end

function Battle:finish(result)
    self.phase = "result"
    self.message = result
    self.messageTimer = 1.3
end

function Battle:exit()
    self.active = false
    local callback = self.onExit
    self.onExit = nil
    if callback then
        callback()
    end
end

function Battle:startEnemyTurn(message)
    self.phase = "enemy"
    self.enemyTimer = 0
    self.spawnTimer = 0
    self.bullets = {}
    self.soul.x = BOX.x + BOX.w / 2 - self.soul.w / 2
    self.soul.y = BOX.y + BOX.h / 2 - self.soul.h / 2
    self.message = message or "The training shape attacks!"
    self.messageTimer = 0.7
end

function Battle:selectMenuOption()
    local option = MENU[self.menuIndex]

    if option == "FIGHT" then
        self.phase = "attack"
        self.attackCursor = 0
        self.attackDirection = 1
        self.message = "Press Z near the center."
        self.messageTimer = 0.9
    elseif option == "ACT" then
        self.enemy.mercy = Util.clamp(self.enemy.mercy + 42, 0, 100)
        self:startEnemyTurn("You compliment its angles. Mercy rose to " .. self.enemy.mercy .. "%.")
    elseif option == "SPARE" then
        if self.enemy.mercy >= 100 then
            self:finish("The training shape was spared. Nobody exploded. Excellent.")
        else
            self:startEnemyTurn("It is not ready to leave yet.")
        end
    elseif option == "FLEE" then
        self:finish("You escaped the optional tutorial fight.")
    end
end

function Battle:resolveAttack()
    local center = 0.5
    local accuracy = 1 - math.min(1, math.abs(self.attackCursor - center) / center)
    local damage = math.floor(8 + accuracy * 26)
    self.enemy.hp = math.max(0, self.enemy.hp - damage)

    if self.enemy.hp <= 0 then
        self:finish("The training shape fell apart into harmless placeholder pixels.")
    else
        self:startEnemyTurn("Hit for " .. damage .. " damage.")
    end
end

function Battle:spawnBullet()
    local elapsed = self.enemyTimer
    local pattern = math.floor(elapsed / 1.5) % 3

    if pattern == 0 then
        table.insert(self.bullets, {
            x = BOX.x + love.math.random(3, BOX.w - 6),
            y = BOX.y - 7,
            w = 5,
            h = 5,
            vx = 0,
            vy = 58 + love.math.random(0, 24),
        })
    elseif pattern == 1 then
        local fromLeft = love.math.random() < 0.5
        table.insert(self.bullets, {
            x = fromLeft and BOX.x - 7 or BOX.x + BOX.w + 2,
            y = BOX.y + love.math.random(3, BOX.h - 8),
            w = 5,
            h = 5,
            vx = fromLeft and 76 or -76,
            vy = love.math.random(-14, 14),
        })
    else
        local angle = elapsed * 2.4
        table.insert(self.bullets, {
            x = BOX.x + BOX.w / 2 + math.cos(angle) * 62,
            y = BOX.y + BOX.h / 2 + math.sin(angle) * 26,
            w = 5,
            h = 5,
            vx = -math.cos(angle) * 34,
            vy = -math.sin(angle) * 34,
        })
    end
end

function Battle:updateEnemyTurn(dt)
    self.enemyTimer = self.enemyTimer + dt
    self.spawnTimer = self.spawnTimer - dt
    self.soul.invulnerability = math.max(0, self.soul.invulnerability - dt)

    local moveX = 0
    local moveY = 0
    if love.keyboard.isDown("left", "a") then moveX = moveX - 1 end
    if love.keyboard.isDown("right", "d") then moveX = moveX + 1 end
    if love.keyboard.isDown("up", "w") then moveY = moveY - 1 end
    if love.keyboard.isDown("down", "s") then moveY = moveY + 1 end
    moveX, moveY = Util.normalize(moveX, moveY)

    self.soul.x = Util.clamp(self.soul.x + moveX * 92 * dt, BOX.x + 2, BOX.x + BOX.w - self.soul.w - 2)
    self.soul.y = Util.clamp(self.soul.y + moveY * 92 * dt, BOX.y + 2, BOX.y + BOX.h - self.soul.h - 2)

    local spawnInterval = math.max(0.10, 0.24 - self.enemyTimer * 0.01)
    if self.spawnTimer <= 0 and self.messageTimer <= 0 then
        self.spawnTimer = spawnInterval
        self:spawnBullet()
    end

    local soulRect = {x = self.soul.x, y = self.soul.y, w = self.soul.w, h = self.soul.h}
    for index = #self.bullets, 1, -1 do
        local bullet = self.bullets[index]
        bullet.x = bullet.x + bullet.vx * dt
        bullet.y = bullet.y + bullet.vy * dt

        local outOfBounds = bullet.x < BOX.x - 20
            or bullet.x > BOX.x + BOX.w + 20
            or bullet.y < BOX.y - 20
            or bullet.y > BOX.y + BOX.h + 20

        if outOfBounds then
            table.remove(self.bullets, index)
        elseif self.soul.invulnerability <= 0 and Util.rectsOverlap(soulRect, bullet) then
            self.soul.hp = math.max(0, self.soul.hp - 8)
            self.soul.invulnerability = 0.75
            table.remove(self.bullets, index)

            if self.soul.hp <= 0 then
                self:finish("The test ended. Press Z to return and try again.")
                return
            end
        end
    end

    if self.enemyTimer >= 6.0 then
        self.phase = "menu"
        self.menuIndex = 1
        self.message = "Your turn."
        self.messageTimer = 0.8
        self.bullets = {}
    end
end

function Battle:update(dt)
    if not self.active then
        return
    end

    self.messageTimer = math.max(0, self.messageTimer - dt)

    if self.phase == "attack" then
        self.attackCursor = self.attackCursor + self.attackDirection * dt * 1.35
        if self.attackCursor >= 1 then
            self.attackCursor = 1
            self.attackDirection = -1
        elseif self.attackCursor <= 0 then
            self.attackCursor = 0
            self.attackDirection = 1
        end
    elseif self.phase == "enemy" then
        self:updateEnemyTurn(dt)
    end
end

function Battle:keypressed(key)
    if not self.active then
        return
    end

    if self.phase == "menu" then
        if key == "left" or key == "a" then
            self.menuIndex = self.menuIndex - 1
            if self.menuIndex < 1 then self.menuIndex = #MENU end
        elseif key == "right" or key == "d" then
            self.menuIndex = self.menuIndex + 1
            if self.menuIndex > #MENU then self.menuIndex = 1 end
        elseif key == "z" or key == "return" or key == "space" then
            self:selectMenuOption()
        end
    elseif self.phase == "attack" then
        if key == "z" or key == "return" or key == "space" then
            self:resolveAttack()
        elseif key == "x" or key == "escape" then
            self.phase = "menu"
        end
    elseif self.phase == "result" then
        if key == "z" or key == "return" or key == "space" or key == "escape" then
            self:exit()
        end
    end
end

function Battle:drawEnemy()
    local bob = math.sin(love.timer.getTime() * 2.2) * 2
    self.assets:draw("enemy", 160, 49 + bob, {centered = true})

    love.graphics.setFont(self.fonts.small)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(self.enemy.name, 88, 78, 144, "center")

    love.graphics.setColor(0.18, 0.18, 0.22, 1)
    love.graphics.rectangle("fill", 108, 90, 104, 5)
    love.graphics.setColor(0.85, 0.18, 0.22, 1)
    love.graphics.rectangle("fill", 108, 90, 104 * (self.enemy.hp / self.enemy.maxHp), 5)

    if self.enemy.mercy > 0 then
        love.graphics.setColor(0.95, 0.84, 0.20, 1)
        love.graphics.print("MERCY " .. self.enemy.mercy .. "%", 222, 87)
    end
end

function Battle:drawBattleBox()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", BOX.x, BOX.y, BOX.w, BOX.h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", BOX.x, BOX.y, BOX.w, BOX.h)

    if self.phase == "enemy" then
        love.graphics.setColor(1, 1, 1, 1)
        for _, bullet in ipairs(self.bullets) do
            love.graphics.rectangle("fill", bullet.x, bullet.y, bullet.w, bullet.h)
        end

        if self.soul.invulnerability <= 0 or math.floor(self.soul.invulnerability * 12) % 2 == 0 then
            love.graphics.setColor(1, 0.12, 0.12, 1)
            love.graphics.polygon(
                "fill",
                self.soul.x + self.soul.w / 2, self.soul.y + self.soul.h,
                self.soul.x, self.soul.y + 2,
                self.soul.x + 2, self.soul.y,
                self.soul.x + self.soul.w / 2, self.soul.y + 2,
                self.soul.x + self.soul.w - 2, self.soul.y,
                self.soul.x + self.soul.w, self.soul.y + 2
            )
        end
    elseif self.phase == "attack" then
        love.graphics.setColor(0.25, 0.25, 0.29, 1)
        love.graphics.rectangle("fill", BOX.x + 8, BOX.y + BOX.h / 2 - 4, BOX.w - 16, 8)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", BOX.x + BOX.w / 2 - 2, BOX.y + 8, 4, BOX.h - 16)
        love.graphics.setColor(1, 0.82, 0.16, 1)
        local cursorX = BOX.x + 8 + (BOX.w - 16) * self.attackCursor
        love.graphics.rectangle("fill", cursorX - 2, BOX.y + 4, 4, BOX.h - 8)
    end
end

function Battle:drawMenu()
    love.graphics.setFont(self.fonts.normal)
    for index, option in ipairs(MENU) do
        local x = 18 + (index - 1) * 76
        if self.phase == "menu" and index == self.menuIndex then
            love.graphics.setColor(1, 0.25, 0.20, 1)
            love.graphics.polygon("fill", x - 9, 211, x - 3, 207, x - 3, 215)
        else
            love.graphics.setColor(0.65, 0.65, 0.70, 1)
        end
        love.graphics.print(option, x, 203)
    end
end

function Battle:drawStatus()
    love.graphics.setFont(self.fonts.small)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("KRIS", 16, 187)
    love.graphics.print("LV 1", 70, 187)
    love.graphics.print("HP", 112, 187)

    love.graphics.setColor(0.22, 0.22, 0.24, 1)
    love.graphics.rectangle("fill", 132, 189, 72, 7)
    love.graphics.setColor(0.98, 0.80, 0.14, 1)
    love.graphics.rectangle("fill", 132, 189, 72 * (self.soul.hp / self.soul.maxHp), 7)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(self.soul.hp .. " / " .. self.soul.maxHp, 212, 187)
end

function Battle:drawMessage()
    if self.message == "" then
        return
    end

    love.graphics.setFont(self.fonts.small)
    love.graphics.setColor(0, 0, 0, 0.90)
    love.graphics.rectangle("fill", 38, 12, 244, 25)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", 38, 12, 244, 25)
    love.graphics.printf(self.message, 44, 17, 232, "center")
end

function Battle:draw()
    love.graphics.clear(0, 0, 0, 1)
    self:drawEnemy()
    self:drawBattleBox()
    self:drawStatus()
    self:drawMenu()
    self:drawMessage()
end

return Battle
