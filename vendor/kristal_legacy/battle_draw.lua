-- Rendering/UI port adapted from Kristal legacy for the existing 320x240 canvas.
local Battle = require("vendor.kristal_legacy.battle_update")
local ctx = Battle._ctx
local Util = ctx.Util
local SW, SH = ctx.SW, ctx.SH
local UI_TOP, STATUS_TOP = ctx.UI_TOP, ctx.STATUS_TOP
local COLORS = ctx.COLORS
local setColor = ctx.setColor
local drawHeart = ctx.drawHeart
local drawOutlinedRect = ctx.drawOutlinedRect

function Battle:drawBackground()
    local alpha = self.state == "TRANSITION" and self.transitionTimer or 1
    love.graphics.clear(0.015, 0.005, 0.025, 1)
    love.graphics.setLineWidth(1)
    for x = -25, SW + 25, 25 do
        setColor({0.25, 0.02, 0.31, alpha * 0.72})
        love.graphics.line(x + self.backgroundOffset, 0, x - 28 + self.backgroundOffset, UI_TOP)
    end
    for y = -25, UI_TOP + 25, 25 do
        setColor({0.25, 0.02, 0.31, alpha * 0.72})
        love.graphics.line(0, y + self.backgroundOffset, SW, y + self.backgroundOffset)
    end
end

function Battle:drawRalsei(x, y, animationTimer)
    local bob = math.sin(animationTimer * 4) * 1.2
    setColor({0.05, 0.12, 0.08, 1})
    love.graphics.polygon("fill", x, y - 18 + bob, x - 9, y - 5 + bob, x + 9, y - 5 + bob)
    setColor({0.35, 0.95, 0.55, 1})
    love.graphics.rectangle("fill", x - 6, y - 12 + bob, 12, 12)
    setColor(COLORS.black)
    love.graphics.rectangle("fill", x - 4, y - 9 + bob, 8, 3)
    setColor({0.20, 0.65, 0.36, 1})
    love.graphics.rectangle("fill", x - 7, y + bob, 14, 12)
    setColor({1, 0.25, 0.55, 1})
    love.graphics.rectangle("fill", x - 6, y + 2 + bob, 12, 2)
end

function Battle:drawPartyMember(member, x, y)
    local bob = 0
    if member.animation == "idle" or member.animation == "victory" then
        bob = math.sin(member.animationTimer * 4 + member.index) * 1.2
    elseif member.animation == "transition" then
        bob = math.sin(member.animationTimer * 15) * 2
    elseif member.animation == "down" then
        bob = 4
    end

    local visible = member.flash <= 0 or math.floor(member.flash * 14) % 2 == 0
    if not visible then return end
    if member.id == "kris" then
        self.assets:draw("hero_down", x, y + bob, {centered = true})
    elseif member.id == "susie" then
        self.assets:draw("friend", x, y + bob, {centered = true})
    else
        self:drawRalsei(x, y + bob, member.animationTimer)
    end

    if member.defending then
        setColor(member.color, 0.55 + math.sin(member.animationTimer * 8) * 0.25)
        love.graphics.circle("line", x, y - 5, 13)
    end
end

function Battle:drawBattlers()
    local positions = {{52, 45}, {50, 91}, {52, 137}}
    local transitionSlide = (1 - (self.state == "TRANSITION" and self.transitionTimer or 1)) * -90
    for index, member in ipairs(self.party) do
        self:drawPartyMember(member, positions[index][1] + transitionSlide, positions[index][2])
    end

    local enemyX = 238 + (1 - (self.state == "TRANSITION" and self.transitionTimer or 1)) * 110
    local enemyY = 77 + math.sin(self.enemy.animationTimer * 2.8) * 2
    if not self.enemy.spared and not self.enemy.defeated then
        self.assets:draw("enemy", enemyX, enemyY, {centered = true})
        if self.enemy.tired then
            love.graphics.setFont(self.fonts.small)
            setColor(COLORS.blue)
            love.graphics.print("Z", enemyX + 15, enemyY - 27)
            love.graphics.print("z", enemyX + 22, enemyY - 34)
        end
    end
end

function Battle:drawTensionBar()
    local x, y, w, h = 6, 73, 9, 77
    setColor({0.35, 0, 0, 1})
    love.graphics.rectangle("fill", x, y, w, h)
    local fill = math.floor((h - 4) * (self.tension / self.maxTension))
    setColor(self.tension >= self.maxTension and COLORS.yellow or COLORS.orange)
    love.graphics.rectangle("fill", x + 2, y + h - 2 - fill, w - 4, fill)
    setColor(self.tensionFlash > 0 and COLORS.white or COLORS.orange)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setFont(self.fonts.tiny)
    love.graphics.printf("TP", 0, 153, 21, "center")
end

function Battle:drawEnemyInfo()
    if self.state ~= "ENEMYSELECT" and self.state ~= "MENUSELECT" then return end
    love.graphics.setFont(self.fonts.small)
    setColor(COLORS.white)
    love.graphics.printf(self.enemy.name, 170, 112, 135, "center")
    setColor({0.25, 0.05, 0.05, 1})
    love.graphics.rectangle("fill", 188, 126, 98, 5)
    setColor(COLORS.green)
    love.graphics.rectangle("fill", 188, 126, 98 * (self.enemy.hp / self.enemy.maxHp), 5)
    if self.enemy.mercy > 0 then
        setColor(self.enemy.mercy >= 100 and COLORS.yellow or COLORS.orange)
        love.graphics.printf("MERCY " .. self.enemy.mercy .. "%", 170, 134, 135, "center")
    end
    if self.state == "ENEMYSELECT" then drawHeart(176, 120, 0.8, COLORS.red) end
end

function Battle:drawStatusBoxes()
    setColor({0.10, 0.04, 0.14, 1})
    love.graphics.rectangle("fill", 0, STATUS_TOP, SW, SH - STATUS_TOP)
    for index, member in ipairs(self.party) do
        local x = (index - 1) * 106
        if index > 1 then
            setColor({0.35, 0.20, 0.40, 1})
            love.graphics.rectangle("fill", x, STATUS_TOP, 1, SH - STATUS_TOP)
        end
        love.graphics.setFont(self.fonts.small)
        setColor(member.down and COLORS.red or member.color)
        love.graphics.print(member.name, x + 6, STATUS_TOP + 4)
        love.graphics.setFont(self.fonts.tiny)
        setColor(COLORS.white)
        love.graphics.print(tostring(member.hp) .. "/" .. tostring(member.maxHp), x + 6, STATUS_TOP + 17)
        setColor({0.35, 0, 0, 1})
        love.graphics.rectangle("fill", x + 49, STATUS_TOP + 18, 49, 5)
        setColor(member.hp <= member.maxHp * 0.25 and COLORS.yellow or COLORS.green)
        love.graphics.rectangle("fill", x + 49, STATUS_TOP + 18, 49 * (member.hp / member.maxHp), 5)
        if self.state == "ACTIONSELECT" and index == self.currentSelecting then
            setColor(member.color)
            love.graphics.rectangle("line", x + 2, STATUS_TOP + 2, 102, 31)
        elseif self.state == "PARTYSELECT" and index == self.currentTarget then
            drawHeart(x + 96, STATUS_TOP + 8, 0.65, COLORS.red)
        end
    end
end

function Battle:drawActionButtons()
    setColor(COLORS.black)
    love.graphics.rectangle("fill", 0, UI_TOP, SW, STATUS_TOP - UI_TOP)
    setColor({0.35, 0.20, 0.40, 1})
    love.graphics.rectangle("fill", 0, UI_TOP, SW, 2)

    if self.state == "ACTIONSELECT" then
        local member = self:getCurrentParty()
        local options = self:getActionOptions(member)
        local widths = {50, 46, 46, 52, 57}
        local total = 0
        for index = 1, #options do total = total + widths[index] end
        local startX = math.floor((SW - total) / 2)
        love.graphics.setFont(self.fonts.small)
        local cursorX = startX
        for index, option in ipairs(options) do
            local width = widths[index]
            local selected = index == self.currentButton
            setColor(selected and member.color or COLORS.gray)
            love.graphics.rectangle("line", cursorX + 2, UI_TOP + 7, width - 4, 23)
            love.graphics.printf(option, cursorX, UI_TOP + 14, width, "center")
            if selected then drawHeart(cursorX + 8, UI_TOP + 18, 0.55, COLORS.red) end
            cursorX = cursorX + width
        end
        love.graphics.setFont(self.fonts.tiny)
        setColor(COLORS.white)
        love.graphics.printf(self.encounterText, 8, UI_TOP + 31, SW - 16, "center")

    elseif self.state == "MENUSELECT" and self.currentMenu then
        love.graphics.setFont(self.fonts.small)
        for index, entry in ipairs(self.currentMenu.entries) do
            local y = UI_TOP + 7 + (index - 1) * 11
            local unusable = entry.unusable or ((entry.tp or 0) > self.tension)
            setColor(unusable and COLORS.gray or COLORS.white)
            if index == self.currentMenuIndex then drawHeart(13, y + 4, 0.55, COLORS.red) end
            love.graphics.print(entry.name, 22, y)
            if entry.tp then
                setColor(unusable and COLORS.gray or COLORS.orange)
                love.graphics.print(tostring(entry.tp) .. "% TP", 244, y)
            end
        end

    elseif self.state == "ENEMYSELECT" then
        love.graphics.setFont(self.fonts.normal)
        setColor(COLORS.white)
        love.graphics.print("* " .. self.enemy.name, 22, UI_TOP + 13)
        drawHeart(13, UI_TOP + 19, 0.55, COLORS.red)

    elseif self.state == "PARTYSELECT" then
        love.graphics.setFont(self.fonts.normal)
        setColor(COLORS.white)
        love.graphics.print("* Choose a party member.", 22, UI_TOP + 13)

    elseif self.state == "BATTLETEXT" then
        love.graphics.setFont(self.fonts.normal)
        setColor(COLORS.white)
        love.graphics.printf(self.textLines[self.textIndex] or "", 13, UI_TOP + 7, SW - 26, "left")

    elseif self.state == "ENEMYDIALOGUE" then
        love.graphics.setFont(self.fonts.normal)
        setColor(COLORS.white)
        love.graphics.printf("* The enemy prepares an attack...", 13, UI_TOP + 13, SW - 26, "left")

    elseif self.state == "DEFENDING" then
        love.graphics.setFont(self.fonts.small)
        setColor(COLORS.white)
        local target = self.party[self.targetedParty]
        love.graphics.printf("TARGET: " .. target.name .. "   Graze bullets to earn TP!", 8, UI_TOP + 15, SW - 16, "center")

    elseif self.state == "ATTACKING" then
        love.graphics.setFont(self.fonts.small)
        setColor(COLORS.white)
        love.graphics.printf("Press Z as each line reaches the center!", 8, UI_TOP + 15, SW - 16, "center")
    end
end

function Battle:drawArena()
    if self.state ~= "DEFENDING" then return end
    drawOutlinedRect(self.arena.x, self.arena.y, self.arena.w, self.arena.h, COLORS.black, COLORS.white, 2)
    setColor(COLORS.white)
    for _, bullet in ipairs(self.bullets) do
        if bullet.grazed then setColor(COLORS.aqua) else setColor(COLORS.white) end
        love.graphics.rectangle("fill", bullet.x, bullet.y, bullet.w, bullet.h)
    end
    if self.soul.invulnerability <= 0 or math.floor(self.soul.invulnerability * 15) % 2 == 0 then
        drawHeart(self.soul.x + self.soul.w / 2, self.soul.y + self.soul.h / 2, 0.75, COLORS.red)
    end
end

function Battle:drawAttackTiming()
    if self.state ~= "ATTACKING" then return end
    local x, y, w = 78, 66, 178
    for index, lane in ipairs(self.attackLanes) do
        local laneY = y + (index - 1) * 25
        setColor({0.13, 0.13, 0.18, 1})
        love.graphics.rectangle("fill", x, laneY, w, 14)
        setColor(COLORS.white)
        love.graphics.rectangle("line", x, laneY, w, 14)
        setColor(COLORS.yellow)
        love.graphics.rectangle("fill", x + w / 2 - 2, laneY + 1, 4, 12)
        local cursorX = x + Util.clamp(lane.position, 0, 1) * w
        local member = self.party[lane.action.character_id]
        setColor(member.color)
        love.graphics.rectangle("fill", cursorX - 2, laneY - 2, 4, 18)
        love.graphics.setFont(self.fonts.tiny)
        setColor(COLORS.white)
        love.graphics.print(member.name, 20, laneY + 3)
        if lane.stopped then
            love.graphics.print(tostring(lane.damage), 264, laneY + 3)
        end
    end
end

function Battle:drawEnemyDialogue()
    if self.state ~= "ENEMYDIALOGUE" or not self.enemyDialogue then return end
    local x, y, w, h = 196, 22, 112, 36
    drawOutlinedRect(x, y, w, h, COLORS.white, COLORS.black, 1)
    setColor(COLORS.black)
    love.graphics.polygon("fill", x + 22, y + h, x + 31, y + h, x + 26, y + h + 8)
    love.graphics.setFont(self.fonts.small)
    love.graphics.printf(self.enemyDialogue, x + 5, y + 7, w - 10, "center")
    local targetPos = {{52, 45}, {50, 91}, {52, 137}}
    local p = targetPos[self.targetedParty]
    setColor(COLORS.red, 0.7 + math.sin(self.enemyDialogueTimer * 12) * 0.3)
    love.graphics.polygon("fill", p[1], p[2] - 25, p[1] - 4, p[2] - 32, p[1] + 4, p[2] - 32)
end

function Battle:drawResult()
    if self.state ~= "RESULT" then return end
    setColor({0, 0, 0, 0.88})
    love.graphics.rectangle("fill", 0, 0, SW, SH)
    love.graphics.setFont(self.fonts.normal)
    setColor(COLORS.white)
    love.graphics.printf(self.result or "Battle ended.", 30, 88, 260, "center")
end

function Battle:draw()
    if not self.active then return end
    self:drawBackground()
    self:drawBattlers()
    self:drawTensionBar()
    self:drawEnemyInfo()
    self:drawArena()
    self:drawAttackTiming()
    self:drawEnemyDialogue()
    self:drawActionButtons()
    self:drawStatusBoxes()
    self:drawResult()

    if self.state == "TRANSITIONOUT" then
        setColor({0, 0, 0, Util.clamp(self.outroTimer / 0.65, 0, 1)})
        love.graphics.rectangle("fill", 0, 0, SW, SH)
    end
end


return Battle
