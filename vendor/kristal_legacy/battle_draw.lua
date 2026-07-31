-- Battle HUD renderer matched to the supplied compact Deltarune references.
-- Battle logic/state remains in the Kristal-derived runtime; this file only draws.
local Battle = require("vendor.kristal_legacy.battle_update")
local ctx = Battle._ctx
local Util = ctx.Util
local SW, SH = ctx.SW, ctx.SH
local UI_TOP = ctx.UI_TOP
local COLORS = ctx.COLORS
local setColor = ctx.setColor
local drawHeart = ctx.drawHeart
local drawOutlinedRect = ctx.drawOutlinedRect

local FIELD_BOTTOM = UI_TOP
local STATUS_Y = UI_TOP + 1
local STATUS_H = 19
local COMMAND_Y = STATUS_Y + STATUS_H + 1
local COMMAND_H = 20
local DIALOGUE_Y = COMMAND_Y + COMMAND_H + 1
local DIALOGUE_H = SH - DIALOGUE_Y

local ACTION_STYLES = {
    FIGHT = {0.98, 0.74, 0.05, 1},
    ACT = {1.00, 0.50, 0.18, 1},
    MAGIC = {0.70, 0.35, 1.00, 1},
    ITEM = {0.22, 1.00, 0.38, 1},
    SPARE = {1.00, 0.34, 0.72, 1},
    DEFEND = {0.18, 0.92, 1.00, 1},
}

local function shade(color, factor, alpha)
    return {
        Util.clamp(color[1] * factor, 0, 1),
        Util.clamp(color[2] * factor, 0, 1),
        Util.clamp(color[3] * factor, 0, 1),
        alpha or color[4] or 1,
    }
end

local function getPartyPositions(count)
    if count <= 1 then
        return {{72, 100}}
    elseif count == 2 then
        return {{65, 105}, {125, 84}}
    end
    return {{57, 108}, {105, 84}, {151, 108}}
end

local function getStatusLayout(count)
    if count <= 1 then
        return 101, 118, 0
    elseif count == 2 then
        return 54, 106, 8
    end
    return 35, 88, 5
end

local function drawSpark(cx, cy, radius)
    love.graphics.polygon(
        "fill",
        cx, cy - radius,
        cx + radius * 0.3, cy - radius * 0.3,
        cx + radius, cy,
        cx + radius * 0.3, cy + radius * 0.3,
        cx, cy + radius,
        cx - radius * 0.3, cy + radius * 0.3,
        cx - radius, cy,
        cx - radius * 0.3, cy - radius * 0.3
    )
end

local function drawActionIcon(action, cx, cy, color)
    setColor(color)
    love.graphics.setLineWidth(1)

    if action == "FIGHT" then
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.rotate(-0.72)
        love.graphics.rectangle("fill", -1, -6, 2, 10)
        love.graphics.rectangle("fill", -4, 3, 8, 2)
        love.graphics.rectangle("fill", -1, 4, 2, 4)
        love.graphics.pop()
    elseif action == "ACT" then
        drawSpark(cx, cy, 6)
        setColor(COLORS.black)
        drawSpark(cx, cy, 2)
    elseif action == "MAGIC" then
        love.graphics.circle("line", cx, cy, 5)
        love.graphics.circle("fill", cx, cy, 1)
        love.graphics.line(cx - 6, cy + 5, cx + 5, cy - 6)
    elseif action == "ITEM" then
        love.graphics.rectangle("line", cx - 5, cy - 2, 10, 8)
        love.graphics.arc("line", "open", cx, cy - 2, 3, math.pi, math.pi * 2)
        love.graphics.rectangle("fill", cx - 1, cy + 1, 2, 3)
    elseif action == "SPARE" then
        love.graphics.polygon("line", cx, cy - 6, cx + 6, cy, cx, cy + 6, cx - 6, cy)
        love.graphics.line(cx - 4, cy, cx + 4, cy)
        love.graphics.line(cx, cy - 4, cx, cy + 4)
    elseif action == "DEFEND" then
        love.graphics.polygon(
            "line",
            cx, cy - 6,
            cx + 5, cy - 4,
            cx + 4, cy + 3,
            cx, cy + 6,
            cx - 4, cy + 3,
            cx - 5, cy - 4
        )
    end
end

function Battle:drawBackground()
    local alpha = self.state == "TRANSITION" and self.transitionTimer or 1
    love.graphics.clear(0.008, 0.002, 0.014, 1)
    love.graphics.setLineWidth(1)

    for x = -30, SW + 30, 24 do
        setColor({0.21, 0.015, 0.27, alpha * 0.7})
        love.graphics.line(x + self.backgroundOffset, 0, x - 25 + self.backgroundOffset, FIELD_BOTTOM)
    end

    for y = 12, FIELD_BOTTOM, 18 do
        setColor({0.16, 0.01, 0.21, alpha * 0.7})
        love.graphics.line(0, y, SW, y)
    end

    setColor({0.35, 0.28, 0.38, 1})
    love.graphics.rectangle("fill", 4, FIELD_BOTTOM - 1, SW - 8, 1)
end

function Battle:drawRalsei(x, y, animationTimer)
    local bob = math.sin(animationTimer * 4) * 1.2
    setColor({0.04, 0.11, 0.07, 1})
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

    if member.flash > 0 and math.floor(member.flash * 14) % 2 ~= 0 then
        return
    end

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
    local positions = getPartyPositions(#self.party)
    local transitionAmount = self.state == "TRANSITION" and self.transitionTimer or 1
    local partySlide = (1 - transitionAmount) * -95

    for index, member in ipairs(self.party) do
        local position = positions[index] or positions[#positions]
        self:drawPartyMember(member, position[1] + partySlide, position[2])
    end

    local enemyX = 244 + (1 - transitionAmount) * 105
    local enemyY = 91 + math.sin(self.enemy.animationTimer * 2.8) * 2
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
    local labelX = 7
    local gaugeX = 24
    local gaugeY = 27
    local gaugeW = 9
    local gaugeH = 89

    love.graphics.setFont(self.fonts.tiny)
    setColor(COLORS.white)
    love.graphics.printf("T", labelX, 39, 10, "center")
    love.graphics.printf("P", labelX, 51, 10, "center")
    love.graphics.printf(tostring(math.floor(self.tension)), labelX - 1, 65, 13, "center")
    love.graphics.printf("%", labelX, 78, 10, "center")

    setColor({0.33, 0.015, 0.01, 1})
    love.graphics.polygon(
        "fill",
        gaugeX, gaugeY + 7,
        gaugeX + gaugeW, gaugeY,
        gaugeX + gaugeW, gaugeY + gaugeH - 7,
        gaugeX, gaugeY + gaugeH
    )

    local ratio = Util.clamp(self.tension / self.maxTension, 0, 1)
    local fillHeight = math.floor((gaugeH - 12) * ratio)
    if fillHeight > 0 then
        setColor(self.tension >= self.maxTension and COLORS.yellow or COLORS.orange)
        love.graphics.rectangle(
            "fill",
            gaugeX + 2,
            gaugeY + gaugeH - 7 - fillHeight,
            gaugeW - 4,
            fillHeight
        )
    end

    if self.tensionFlash > 0 then
        setColor(COLORS.white)
        love.graphics.setLineWidth(1)
        love.graphics.line(gaugeX, gaugeY + 7, gaugeX + gaugeW, gaugeY)
        love.graphics.line(gaugeX + gaugeW, gaugeY, gaugeX + gaugeW, gaugeY + gaugeH - 7)
        love.graphics.line(gaugeX + gaugeW, gaugeY + gaugeH - 7, gaugeX, gaugeY + gaugeH)
    end
end

local function drawMiniPortrait(member, x, y)
    setColor(shade(member.color, 0.36))
    love.graphics.circle("fill", x, y, 7)
    setColor(member.color)

    if member.id == "kris" then
        love.graphics.rectangle("fill", x - 4, y - 3, 8, 6)
        setColor({0.06, 0.08, 0.18, 1})
        love.graphics.rectangle("fill", x - 5, y - 5, 10, 3)
    elseif member.id == "susie" then
        love.graphics.polygon("fill", x - 5, y - 5, x + 3, y - 5, x + 5, y + 5, x - 4, y + 5)
    else
        love.graphics.polygon("fill", x, y - 6, x - 6, y, x + 6, y)
        love.graphics.rectangle("fill", x - 4, y, 8, 5)
    end
end

function Battle:drawOneStatusPanel(member, index, x, y, w, selected)
    local panelColor = member.down and COLORS.red or member.color

    setColor(COLORS.black)
    love.graphics.rectangle("fill", x, y, w, STATUS_H)

    setColor(shade(panelColor, 0.24))
    love.graphics.rectangle("fill", x + 1, y + 1, w - 2, STATUS_H - 2)

    if selected then
        setColor(panelColor)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x, y, w, STATUS_H)
        setColor(COLORS.white)
        love.graphics.rectangle("line", x + 2, y + 2, w - 4, STATUS_H - 4)
    else
        setColor(shade(panelColor, 0.72))
        love.graphics.rectangle("line", x, y, w, STATUS_H)
    end

    drawMiniPortrait(member, x + 12, y + 9)

    love.graphics.setFont(self.fonts.small)
    setColor(COLORS.white)
    love.graphics.print(member.name, x + 23, y + 2)

    love.graphics.setFont(self.fonts.tiny)
    setColor(COLORS.white)
    love.graphics.print("HP", x + 23, y + 11)
    love.graphics.print(tostring(member.hp) .. "/" .. tostring(member.maxHp), x + 36, y + 11)

    local barX = x + w - 29
    local barY = y + 12
    setColor({0.25, 0.02, 0.04, 1})
    love.graphics.rectangle("fill", barX, barY, 25, 4)
    setColor(member.hp <= member.maxHp * 0.25 and COLORS.yellow or COLORS.green)
    love.graphics.rectangle("fill", barX, barY, 25 * Util.clamp(member.hp / member.maxHp, 0, 1), 4)

    if self.state == "PARTYSELECT" and index == self.currentTarget then
        drawHeart(x + w - 8, y + 7, 0.45, COLORS.red)
    elseif self:hasAction(index) then
        setColor(panelColor)
        drawSpark(x + w - 7, y + 6, 3)
    end
end

function Battle:drawStatusBoxes()
    if self.state == "ATTACKING" then
        return
    end

    local count = #self.party
    local startX, panelW, gap = getStatusLayout(count)

    for index, member in ipairs(self.party) do
        local x = startX + (index - 1) * (panelW + gap)
        local selected = self.state == "ACTIONSELECT" and index == self.currentSelecting
        self:drawOneStatusPanel(member, index, x, STATUS_Y, panelW, selected)
    end
end

function Battle:drawCommandButtons()
    if self.state ~= "ACTIONSELECT" then
        return
    end

    local member = self:getCurrentParty()
    if not member then
        return
    end

    local count = #self.party
    local startX, panelW, gap = getStatusLayout(count)
    local statusX = startX + (self.currentSelecting - 1) * (panelW + gap)
    local options = self:getActionOptions(member)
    local buttonW = 20
    local buttonGap = 2
    local totalW = #options * buttonW + (#options - 1) * buttonGap
    local rowX = math.floor(statusX + panelW / 2 - totalW / 2)
    rowX = Util.clamp(rowX, 38, SW - totalW - 4)

    for index, option in ipairs(options) do
        local x = rowX + (index - 1) * (buttonW + buttonGap)
        local selected = index == self.currentButton
        local color = ACTION_STYLES[option] or member.color

        setColor(COLORS.black)
        love.graphics.rectangle("fill", x, COMMAND_Y, buttonW, COMMAND_H)

        setColor(selected and COLORS.white or color)
        love.graphics.setLineWidth(selected and 2 or 1)
        love.graphics.rectangle("line", x, COMMAND_Y, buttonW, COMMAND_H)

        drawActionIcon(option, x + buttonW / 2, COMMAND_Y + 7, color)

        love.graphics.setFont(self.fonts.tiny)
        setColor(selected and COLORS.white or color)
        love.graphics.printf(option, x - 3, COMMAND_Y + 13, buttonW + 6, "center")

        if selected then
            drawHeart(x + 3, COMMAND_Y + 4, 0.32, COLORS.red)
        end
    end
end

function Battle:drawDialogueBox()
    if self.state == "ATTACKING" then
        return
    end

    setColor(COLORS.black)
    love.graphics.rectangle("fill", 0, DIALOGUE_Y, SW, DIALOGUE_H)
    setColor({0.34, 0.28, 0.38, 1})
    love.graphics.rectangle("fill", 4, DIALOGUE_Y, SW - 8, 1)

    if self.state == "ACTIONSELECT" then
        love.graphics.setFont(self.fonts.normal)
        setColor(COLORS.white)
        love.graphics.printf(self.encounterText, 17, DIALOGUE_Y + 9, SW - 28, "left")

    elseif self.state == "MENUSELECT" and self.currentMenu then
        love.graphics.setFont(self.fonts.small)
        for index, entry in ipairs(self.currentMenu.entries) do
            local column = (index - 1) % 2
            local row = math.floor((index - 1) / 2)
            local x = 27 + column * 145
            local y = DIALOGUE_Y + 6 + row * 13
            local unusable = entry.unusable or ((entry.tp or 0) > self.tension)

            if index == self.currentMenuIndex then
                drawHeart(x - 9, y + 5, 0.45, COLORS.red)
            end

            setColor(unusable and COLORS.gray or COLORS.white)
            love.graphics.print(entry.name, x, y)

            if entry.tp then
                love.graphics.setFont(self.fonts.tiny)
                setColor(unusable and COLORS.gray or COLORS.orange)
                love.graphics.print(tostring(entry.tp) .. "% TP", x + 83, y + 2)
                love.graphics.setFont(self.fonts.small)
            end
        end

    elseif self.state == "ENEMYSELECT" then
        love.graphics.setFont(self.fonts.normal)
        setColor(COLORS.white)
        drawHeart(18, DIALOGUE_Y + 15, 0.5, COLORS.red)
        love.graphics.print("* " .. self.enemy.name, 29, DIALOGUE_Y + 8)

        love.graphics.setFont(self.fonts.tiny)
        setColor({0.25, 0.04, 0.05, 1})
        love.graphics.rectangle("fill", 29, DIALOGUE_Y + 25, 112, 4)
        setColor(COLORS.green)
        love.graphics.rectangle(
            "fill",
            29,
            DIALOGUE_Y + 25,
            112 * Util.clamp(self.enemy.hp / self.enemy.maxHp, 0, 1),
            4
        )

        if self.enemy.mercy > 0 then
            setColor(self.enemy.mercy >= 100 and COLORS.yellow or COLORS.orange)
            love.graphics.print("MERCY " .. self.enemy.mercy .. "%", 154, DIALOGUE_Y + 22)
        end

    elseif self.state == "PARTYSELECT" then
        love.graphics.setFont(self.fonts.normal)
        setColor(COLORS.white)
        love.graphics.print("* Choose a party member.", 18, DIALOGUE_Y + 9)

    elseif self.state == "BATTLETEXT" then
        love.graphics.setFont(self.fonts.normal)
        setColor(COLORS.white)
        love.graphics.printf(self.textLines[self.textIndex] or "", 17, DIALOGUE_Y + 7, SW - 30, "left")

    elseif self.state == "ENEMYDIALOGUE" then
        love.graphics.setFont(self.fonts.normal)
        setColor(COLORS.white)
        love.graphics.print("* The enemy prepares an attack...", 17, DIALOGUE_Y + 9)

    elseif self.state == "DEFENDING" then
        local target = self.party[self.targetedParty]
        love.graphics.setFont(self.fonts.small)
        setColor(COLORS.white)
        love.graphics.printf(
            "TARGET: " .. target.name .. "   Graze bullets to earn TP!",
            10,
            DIALOGUE_Y + 11,
            SW - 20,
            "center"
        )
    end
end

function Battle:drawEnemyInfo()
    -- Enemy information is intentionally kept inside the dialogue box,
    -- matching the compact references instead of floating over the field.
end

function Battle:drawArena()
    if self.state ~= "DEFENDING" then
        return
    end

    drawOutlinedRect(self.arena.x, self.arena.y, self.arena.w, self.arena.h, COLORS.black, COLORS.white, 2)

    for _, bullet in ipairs(self.bullets) do
        setColor(bullet.grazed and COLORS.aqua or COLORS.white)
        love.graphics.rectangle("fill", bullet.x, bullet.y, bullet.w, bullet.h)
    end

    if self.soul.invulnerability <= 0 or math.floor(self.soul.invulnerability * 15) % 2 == 0 then
        drawHeart(self.soul.x + self.soul.w / 2, self.soul.y + self.soul.h / 2, 0.75, COLORS.red)
    end
end

function Battle:drawAttackTiming()
    if self.state ~= "ATTACKING" then
        return
    end

    setColor(COLORS.black)
    love.graphics.rectangle("fill", 0, UI_TOP, SW, SH - UI_TOP)
    setColor({0.34, 0.28, 0.38, 1})
    love.graphics.rectangle("fill", 10, UI_TOP, SW - 20, 1)

    local laneCount = math.max(1, #self.attackLanes)
    local rowH = math.floor((SH - UI_TOP - 4) / laneCount)

    for index, lane in ipairs(self.attackLanes) do
        local member = self.party[lane.action.character_id]
        local rowY = UI_TOP + 2 + (index - 1) * rowH
        local statusY = rowY
        local laneY = rowY + 13
        local laneX = 47
        local laneW = 112

        drawMiniPortrait(member, 18, rowY + 9)

        love.graphics.setFont(self.fonts.small)
        setColor(COLORS.white)
        love.graphics.print(member.name, 31, statusY + 1)

        love.graphics.setFont(self.fonts.tiny)
        love.graphics.print("HP", 78, statusY + 4)
        love.graphics.print(tostring(member.hp) .. "/" .. tostring(member.maxHp), 92, statusY + 4)

        setColor({0.18, 0.18, 0.23, 1})
        love.graphics.rectangle("fill", laneX, laneY, laneW, 9)
        setColor(member.color)
        love.graphics.rectangle("line", laneX, laneY, laneW, 9)

        for marker = 1, 5 do
            local markerX = laneX + math.floor(laneW * marker / 6)
            setColor({0.32, 0.32, 0.36, 1})
            love.graphics.rectangle("fill", markerX, laneY + 1, 2, 7)
        end

        setColor(COLORS.white)
        love.graphics.rectangle("fill", laneX + math.floor(laneW / 2) - 1, laneY, 3, 9)

        local cursorX = laneX + Util.clamp(lane.position, 0, 1) * laneW
        setColor(member.color)
        love.graphics.rectangle("fill", cursorX - 1, laneY - 2, 3, 13)

        if lane.stopped then
            love.graphics.setFont(self.fonts.small)
            setColor(COLORS.white)
            love.graphics.print(tostring(lane.damage), 172, laneY - 2)
        else
            love.graphics.setFont(self.fonts.tiny)
            setColor(COLORS.white)
            love.graphics.print("PRESS Z", 172, laneY)
        end
    end
end

function Battle:drawEnemyDialogue()
    if self.state ~= "ENEMYDIALOGUE" or not self.enemyDialogue then
        return
    end

    local x, y, w, h = 198, 22, 108, 34
    drawOutlinedRect(x, y, w, h, COLORS.white, COLORS.black, 1)
    setColor(COLORS.white)
    love.graphics.polygon("fill", x + 27, y + h, x + 35, y + h, x + 31, y + h + 7)
    setColor(COLORS.black)
    love.graphics.polygon("fill", x + 28, y + h - 1, x + 34, y + h - 1, x + 31, y + h + 5)

    love.graphics.setFont(self.fonts.small)
    setColor(COLORS.black)
    love.graphics.printf(self.enemyDialogue, x + 5, y + 7, w - 10, "center")

    local positions = getPartyPositions(#self.party)
    local position = positions[self.targetedParty] or positions[1]
    setColor(COLORS.red, 0.7 + math.sin(self.enemyDialogueTimer * 12) * 0.3)
    love.graphics.polygon(
        "fill",
        position[1], position[2] - 27,
        position[1] - 4, position[2] - 34,
        position[1] + 4, position[2] - 34
    )
end

function Battle:drawResult()
    if self.state ~= "RESULT" then
        return
    end

    setColor({0, 0, 0, 0.88})
    love.graphics.rectangle("fill", 0, 0, SW, SH)
    love.graphics.setFont(self.fonts.normal)
    setColor(COLORS.white)
    love.graphics.printf(self.result or "Battle ended.", 30, 88, 260, "center")
end

function Battle:drawActionButtons()
    self:drawCommandButtons()
    self:drawDialogueBox()
end

function Battle:draw()
    if not self.active then
        return
    end

    self:drawBackground()
    self:drawBattlers()
    self:drawTensionBar()
    self:drawArena()
    self:drawAttackTiming()
    self:drawEnemyDialogue()
    self:drawStatusBoxes()
    self:drawActionButtons()
    self:drawResult()

    if self.state == "TRANSITIONOUT" then
        setColor({0, 0, 0, Util.clamp(self.outroTimer / 0.65, 0, 1)})
        love.graphics.rectangle("fill", 0, 0, SW, SH)
    end
end

return Battle
