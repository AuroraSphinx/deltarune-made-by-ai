-- Update/input/wave processing ported from Kristal legacy.
local Battle = require("vendor.kristal_legacy.battle_actions")
local ctx = Battle._ctx
local Util = ctx.Util
local rectsOverlap = ctx.rectsOverlap
local distanceToRect = ctx.distanceToRect
local isConfirm = ctx.isConfirm
local isCancel = ctx.isCancel
local wrap = ctx.wrap

function Battle:updateTransition(dt)
    self.transitionTimer = math.min(1, self.transitionTimer + dt * 2.8)
    if self.transitionTimer >= 1 then self:setState("INTRO") end
end

function Battle:updateIntro(dt)
    self.introTimer = self.introTimer + dt
    if self.introTimer >= 0.65 then self:setState("ACTIONSELECT") end
end

function Battle:updateActions(dt)
    self.actionDelay = math.max(0, self.actionDelay - dt)
    if self.actionDelay <= 0 then self:tryProcessNextAction() end
end

function Battle:updateAttacking(dt)
    if #self.attackLanes == 0 then
        self:setState("ENEMYDIALOGUE")
        return
    end

    for _, lane in ipairs(self.attackLanes) do
        if not lane.stopped then lane.position = lane.position + lane.speed * dt end
    end

    local lane = self.attackLanes[self.attackLaneIndex]
    if lane and not lane.stopped and lane.position > 1.08 then
        self:resolveAttackLane(lane)
        self.attackLaneIndex = self.attackLaneIndex + 1
    end

    if self.attackLaneIndex > #self.attackLanes then
        self.attackResultTimer = self.attackResultTimer + dt
        if self.attackResultTimer >= 0.45 then self:finishAttacks() end
    end
end

function Battle:updateEnemyDialogue(dt)
    self.enemyDialogueTimer = self.enemyDialogueTimer + dt
    if self.enemyDialogueTimer >= 1.15 then self:setState("DIALOGUEEND") end
end

function Battle:updateDefending(dt)
    self.waveTimer = self.waveTimer + dt
    self.spawnTimer = self.spawnTimer - dt
    self.soul.invulnerability = math.max(0, self.soul.invulnerability - dt)

    local dx, dy = 0, 0
    if love.keyboard.isDown("left", "a") then dx = dx - 1 end
    if love.keyboard.isDown("right", "d") then dx = dx + 1 end
    if love.keyboard.isDown("up", "w") then dy = dy - 1 end
    if love.keyboard.isDown("down", "s") then dy = dy + 1 end
    dx, dy = Util.normalize(dx, dy)
    self.soul.x = Util.clamp(self.soul.x + dx * self.soul.speed * dt, self.arena.x + 2, self.arena.x + self.arena.w - self.soul.w - 2)
    self.soul.y = Util.clamp(self.soul.y + dy * self.soul.speed * dt, self.arena.y + 2, self.arena.y + self.arena.h - self.soul.h - 2)

    local interval = self.wavePattern == 3 and 0.18 or 0.25
    if self.spawnTimer <= 0 then
        self.spawnTimer = interval
        self:spawnBullet()
    end

    local soulRect = {x = self.soul.x, y = self.soul.y, w = self.soul.w, h = self.soul.h}
    local sx, sy = self.soul.x + self.soul.w / 2, self.soul.y + self.soul.h / 2
    for index = #self.bullets, 1, -1 do
        local bullet = self.bullets[index]
        bullet.x = bullet.x + bullet.vx * dt
        bullet.y = bullet.y + bullet.vy * dt
        local out = bullet.x < self.arena.x - 25 or bullet.x > self.arena.x + self.arena.w + 25
            or bullet.y < self.arena.y - 25 or bullet.y > self.arena.y + self.arena.h + 25
        if out then
            table.remove(self.bullets, index)
        elseif rectsOverlap(soulRect, bullet) then
            if self.soul.invulnerability <= 0 then
                self:hurtParty(self.targetedParty, bullet.damage)
                self.soul.invulnerability = 0.72
            end
            table.remove(self.bullets, index)
        elseif not bullet.grazed and distanceToRect(sx, sy, bullet) <= 9 then
            bullet.grazed = true
            self:addTension(3)
        end
    end

    if self.waveTimer >= self.waveLength and self.state == "DEFENDING" then
        self:setState("ACTIONSELECT")
    end
end

function Battle:updateText(dt)
    if self.textAutoTimer then
        self.textAutoTimer = self.textAutoTimer - dt
        if self.textAutoTimer <= 0 then self:advanceText() end
    end
end

function Battle:updateOutro(dt)
    self.outroTimer = self.outroTimer + dt
    if self.outroTimer >= 0.65 then self:exit() end
end

function Battle:update(dt)
    if not self.active then return end
    self.backgroundOffset = (self.backgroundOffset + dt * 18) % 25
    self.tensionFlash = math.max(0, self.tensionFlash - dt)
    for _, member in ipairs(self.party) do
        member.flash = math.max(0, member.flash - dt)
        member.animationTimer = member.animationTimer + dt
    end
    if self.enemy then self.enemy.animationTimer = self.enemy.animationTimer + dt end

    if self.state == "TRANSITION" then
        self:updateTransition(dt)
    elseif self.state == "INTRO" then
        self:updateIntro(dt)
    elseif self.state == "ACTIONS" then
        self:updateActions(dt)
    elseif self.state == "ATTACKING" then
        self:updateAttacking(dt)
    elseif self.state == "ENEMYDIALOGUE" then
        self:updateEnemyDialogue(dt)
    elseif self.state == "DEFENDING" then
        self:updateDefending(dt)
    elseif self.state == "BATTLETEXT" then
        self:updateText(dt)
    elseif self.state == "TRANSITIONOUT" then
        self:updateOutro(dt)
    elseif self.state == "RESULT" then
        self.resultTimer = self.resultTimer + dt
    end
end

function Battle:keypressed(key)
    if not self.active then return end

    if self.state == "ACTIONSELECT" then
        local member = self:getCurrentParty()
        if not member then return end
        local count = #self:getActionOptions(member)
        if key == "left" or key == "a" then
            self.currentButton = wrap(self.currentButton - 1, count)
        elseif key == "right" or key == "d" then
            self.currentButton = wrap(self.currentButton + 1, count)
        elseif isConfirm(key) then
            self:selectActionButton()
        elseif isCancel(key) then
            self:cancelCurrentSelection()
        end

    elseif self.state == "ENEMYSELECT" then
        if isConfirm(key) then self:selectEnemy()
        elseif isCancel(key) then self.state = "ACTIONSELECT" end

    elseif self.state == "PARTYSELECT" then
        if key == "left" or key == "a" or key == "up" or key == "w" then
            repeat self.currentTarget = wrap(self.currentTarget - 1, #self.party)
            until self.party[self.currentTarget].hp > 0
        elseif key == "right" or key == "d" or key == "down" or key == "s" then
            repeat self.currentTarget = wrap(self.currentTarget + 1, #self.party)
            until self.party[self.currentTarget].hp > 0
        elseif isConfirm(key) then self:selectPartyTarget()
        elseif isCancel(key) then self.state = "ACTIONSELECT" end

    elseif self.state == "MENUSELECT" then
        local count = self.currentMenu and #self.currentMenu.entries or 0
        if key == "up" or key == "w" or key == "left" or key == "a" then
            self.currentMenuIndex = wrap(self.currentMenuIndex - 1, count)
        elseif key == "down" or key == "s" or key == "right" or key == "d" then
            self.currentMenuIndex = wrap(self.currentMenuIndex + 1, count)
        elseif isConfirm(key) then self:selectMenuEntry()
        elseif isCancel(key) then
            self.currentMenu = nil
            self.state = "ACTIONSELECT"
        end

    elseif self.state == "ATTACKING" then
        if isConfirm(key) then
            local lane = self.attackLanes[self.attackLaneIndex]
            if lane and not lane.stopped then
                self:resolveAttackLane(lane)
                self.attackLaneIndex = self.attackLaneIndex + 1
            end
        end

    elseif self.state == "BATTLETEXT" then
        if isConfirm(key) or isCancel(key) then self:advanceText() end

    elseif self.state == "RESULT" then
        if isConfirm(key) or isCancel(key) then self:exit() end
    end
end


return Battle
