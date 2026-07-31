-- Deltarune-inspired battle renderer for the existing 320x240 canvas.
-- The state machine and battle logic remain in the Kristal-derived port; this
-- file only owns layout, colors, icons, battlers, and HUD presentation.
local Battle = require("vendor.kristal_legacy.battle_update")
local ctx = Battle._ctx
local Util = ctx.Util
local SW, SH = ctx.SW, ctx.SH
local UI_TOP, STATUS_TOP = ctx.UI_TOP, ctx.STATUS_TOP
local COLORS = ctx.COLORS
local setColor = ctx.setColor
local drawHeart = ctx.drawHeart
local drawOutlinedRect = ctx.drawOutlinedRect

local TP_X = 282
local TP_W = SW - TP_X
local PARTY_PANEL_W = 94
local PORTRAIT_W = 42
local COMMAND_W = 48
local BATTLE_POSITIONS = {
    {82, 119},
    {126, 98},
    {170, 119},
}

local ACTION_STYLES = {
    FIGHT = {
        dark = {0.36, 0.055, 0.025, 1},
        bright = {1.00, 0.28, 0.08, 1},
    },
    ACT = {
        dark = {0.36, 0.27, 0.015, 1},
        bright = {1.00, 0.82, 0.05, 1},
    },
    MAGIC = {
        dark = {0.28, 0.09, 0.36, 1},
        bright = {0.73, 0.32, 1.00, 1},
    },
    ITEM = {
        dark = {0.025, 0.28, 0.075, 1},
        bright = {0.20, 1.00, 0.36, 1},
    },
    SPARE = {
        dark = {0.34, 0.07, 0.19, 1},
        bright = {1.00, 0.28, 0.68, 1},
    },
    DEFEND = {
        dark = {0.02, 0.23, 0.29, 1},
        bright = {0.20, 0.92, 1.00, 1},
    },
}

local function shade(color, amount, alpha)
    return {
        Util.clamp(color[1] * amount, 0, 1),
        Util.clamp(color[2] * amount, 0, 1),
        Util.clamp(color[3] * amount, 0, 1),
        alpha or color[4] or 1,
    }
end

local function drawSpark(cx, cy, radius)
    love.graphics.polygon(
        "fill",
        cx, cy - radius,
        cx + radius * 0.30, cy - radius * 0.30,
        cx + radius, cy,
        cx + radius * 0.30, cy + radius * 0.30,
        cx, cy + radius,
        cx - radius * 0.30, cy + radius * 0.30,
        cx - radius, cy,
        cx - radius * 0.30, cy - radius * 0.30
    )
end

local function drawActionIcon(action, cx, cy, color)
    setColor(color)
    love.graphics.setLineWidth(2)

    if action == "FIGHT" then
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.rotate(-0.72)
        love.graphics.rectangle("fill", -2, -10, 4, 17)
        love.graphics.rectangle("fill", -7, 5, 14, 3)
        love.graphics.rectangle("fill", -2, 7, 4, 6)
        love.graphics.pop()

    elseif action == "ACT" then
        drawSpark(cx, cy, 10)
        setColor(COLORS.black)
        drawSpark(cx, cy, 4)

    elseif action == "MAGIC" then
        love.graphics.circle("line", cx, cy, 9)
        love.graphics.circle("fill", cx, cy, 3)
        love.graphics.line(cx - 11, cy + 9, cx + 9, cy - 11)
        love.graphics.circle("fill", cx + 9, cy - 11, 2)

    elseif action == "ITEM" then
        love.graphics.rectangle("line", cx - 9, cy - 4, 18, 14, 2, 2)
        love.graphics.arc("line", "open", cx, cy - 4, 6, math.pi, math.pi * 2)
        love.graphics.rectangle("fill", cx - 2, cy + 1, 4, 5)

    elseif action == "SPARE" then
        love.graphics.polygon(
            "line",
            cx, cy - 11,
            cx + 10, cy,
            cx, cy + 11,
            cx - 10, cy
        )
        love.graphics.line(cx - 7, cy, cx + 7, cy)
        love.graphics.line(cx, cy - 7, cx, cy + 7)

    elseif action == "DEFEND" then
        love.graphics.polygon(
            "line",
            cx, cy - 11,
            cx + 9, cy - 7,
            cx + 7, cy + 5,
            cx, cy + 11,
            cx - 7, cy + 5,
            cx - 9, cy - 7
        )
        love.graphics.line(cx, cy - 7, cx, cy + 7)
    end
end

function Battle:drawBackground()
    local alpha = self.state == "TRANSITION" and self.transitionTimer or 1
    love.graphics.clear(0.012, 0.003, 0.022, 1)

    love.graphics.setLineWidth(1)
    for x = -40, SW + 40, 24 do
        setColor({0.28, 0.015, 0.35, alpha * 0.68})
        love.graphics.line(
            x + self.backgroundOffset,
            0,
            x - 38 + self.backgroundOffset,
            UI_TOP
        )
    end

    for y = 8, UI_TOP, 18 do
        setColor({0.15, 0.005, 0.22, alpha * 0.65})
        love.graphics.line(0, y, SW, y)
    end

    setColor({0.46, 0.04, 0.55, alpha * 0.75})
    love.graphics.line(0, UI_TOP - 1, SW, UI_TOP - 1)
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

    local visible = member.flash <= 0 or math.floor(member.flash * 14) % 2 == 0
    if not visible then return end

    setColor({0, 0, 0, 0.45})
    love.graphics.ellipse("fill", x, y + 13, 13, 4)

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
    local transitionAmount = self.state == "TRANSITION" and self.transitionTimer or 1
    local partySlide = (1 - transitionAmount) * -110

    for index, member in ipairs(self.party) do
        local position = BATTLE_POSITIONS[index]
        self:drawPartyMember(member, position[1] + partySlide, position[2])

        if self.state == "ACTIONSELECT" and index == self.currentSelecting then
            setColor(member.color, 0.45 + math.sin(member.animationTimer * 8) * 0.15)
            love.graphics.ellipse("line", position[1] + partySlide, position[2] + 14, 15, 5)
        end
    end

    local enemyX = 246 + (1 - transitionAmount) * 110
    local enemyY = 91 + math.sin(self.enemy.animationTimer * 2.8) * 2
    if not self.enemy.spared and not self.enemy.defeated then
        setColor({0, 0, 0, 0.45})
        love.graphics.ellipse("fill", enemyX, enemyY + 18, 18, 5)
        self.assets:draw("enemy", enemyX, enemyY, {centered = true})

        if self.enemy.tired then
            love.graphics.setFont(self.fonts.small)
            setColor(COLORS.blue)
            love.graphics.print("Z", enemyX + 15, enemyY - 27)
            love.graphics.print("z", enemyX + 22, enemyY - 34)
        end
    end
end

function Battle:drawCommandPortrait(member)
    setColor(shade(member.color, 0.22))
    love.graphics.rectangle("fill", 0, UI_TOP, PORTRAIT_W, STATUS_TOP - UI_TOP)

    setColor(shade(member.color, 0.72))
    love.graphics.rectangle("fill", 2, UI_TOP + 2, PORTRAIT_W - 4, STATUS_TOP - UI_TOP - 4)

    local cx = math.floor(PORTRAIT_W / 2)
    local cy = UI_TOP + 18

    if member.id == "kris" then
        setColor({0.11, 0.18, 0.35, 1})
        love.graphics.rectangle("fill", cx - 9, cy - 10, 18, 19)
        setColor({0.10, 0.47, 0.68, 1})
        love.graphics.rectangle("fill", cx - 8, cy - 4, 16, 12)
        setColor({0.05, 0.08, 0.18, 1})
        love.graphics.polygon("fill", cx - 10, cy - 10, cx + 10, cy - 10, cx + 8, cy - 1, cx - 8, cy + 1)

    elseif member.id == "susie" then
        setColor({0.48, 0.10, 0.40, 1})
        love.graphics.polygon("fill", cx - 10, cy - 10, cx + 7, cy - 10, cx + 10, cy + 8, cx - 8, cy + 9)
        setColor({0.96, 0.78, 0.30, 1})
        love.graphics.rectangle("fill", cx + 2, cy, 6, 2)
        setColor(COLORS.white)
        love.graphics.rectangle("fill", cx + 2, cy + 4, 6, 2)

    else
        setColor({0.03, 0.11, 0.07, 1})
        love.graphics.polygon("fill", cx, cy - 13, cx - 12, cy - 1, cx + 12, cy - 1)
        setColor({0.36, 0.95, 0.55, 1})
        love.graphics.rectangle("fill", cx - 8, cy - 3, 16, 12)
        setColor({0.05, 0.08, 0.08, 1})
        love.graphics.rectangle("fill", cx - 5, cy, 10, 3)
        setColor({1.00, 0.28, 0.62, 1})
        love.graphics.rectangle("fill", cx - 8, cy + 8, 16, 2)
    end

    love.graphics.setFont(self.fonts.tiny)
    setColor(COLORS.white)
    love.graphics.printf(member.name, 0, UI_TOP + 31, PORTRAIT_W, "center")
end

function Battle:drawTensionBar()
    local y = UI_TOP
    local h = SH - UI_TOP
    local gaugeX = TP_X + 8
    local gaugeY = UI_TOP + 6
    local gaugeW = 12
    local gaugeH = h - 25

    setColor({0.08, 0.025, 0.015, 1})
    love.graphics.rectangle("fill", TP_X, y, TP_W, h)
    setColor({0.55, 0.19, 0.02, 1})
    love.graphics.rectangle("fill", TP_X, y, 2, h)

    setColor({0.34, 0.08, 0.01, 1})
    love.graphics.rectangle("fill", gaugeX, gaugeY, gaugeW, gaugeH)

    local ratio = Util.clamp(self.tension / self.maxTension, 0, 1)
    local fill = math.floor((gaugeH - 4) * ratio)
    local gaugeColor = self.tension >= self.maxTension and COLORS.yellow or COLORS.orange
    setColor(gaugeColor)
    love.graphics.rectangle("fill", gaugeX + 2, gaugeY + gaugeH - 2 - fill, gaugeW - 4, fill)

    setColor(self.tensionFlash > 0 and COLORS.white or COLORS.orange)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", gaugeX, gaugeY, gaugeW, gaugeH)

    love.graphics.setFont(self.fonts.tiny)
    setColor(COLORS.white)
    love.graphics.printf(tostring(math.floor(self.tension)) .. "%", TP_X, UI_TOP + 3, TP_W, "center")
    setColor(COLORS.orange)
    love.graphics.printf("TP", TP_X, SH - 13, TP_W, "center")
end

function Battle:drawEnemyInfo()
    if self.state ~= "ENEMYSELECT" and self.state ~= "MENUSELECT" then return end

    local x, y, w = 177, 126, 132
    setColor({0, 0, 0, 0.72})
    love.graphics.rectangle("fill", x - 4, y - 4, w + 8, 28)

    love.graphics.setFont(self.fonts.small)
    setColor(COLORS.white)
    love.graphics.printf(self.enemy.name, x, y, w, "center")

    setColor({0.25, 0.05, 0.05, 1})
    love.graphics.rectangle("fill", x + 15, y + 13, w - 30, 4)
    setColor(COLORS.green)
    love.graphics.rectangle("fill", x + 15, y + 13, (w - 30) * (self.enemy.hp / self.enemy.maxHp), 4)

    if self.enemy.mercy > 0 then
        love.graphics.setFont(self.fonts.tiny)
        setColor(self.enemy.mercy >= 100 and COLORS.yellow or COLORS.orange)
        love.graphics.printf("MERCY " .. self.enemy.mercy .. "%", x, y + 19, w, "center")
    end

    if self.state == "ENEMYSELECT" then
        drawHeart(x + 7, y + 7, 0.7, COLORS.red)
    end
end

function Battle:drawStatusBoxes()
    setColor({0.025, 0.01, 0.04, 1})
    love.graphics.rectangle("fill", 0, STATUS_TOP, TP_X, SH - STATUS_TOP)

    for index, member in ipairs(self.party) do
        local x = (index - 1) * PARTY_PANEL_W
        local panelH = SH - STATUS_TOP

        setColor(shade(member.color, 0.12))
        love.graphics.rectangle("fill", x, STATUS_TOP, PARTY_PANEL_W, panelH)

        setColor(shade(member.color, 0.62))
        love.graphics.rectangle("fill", x, STATUS_TOP, PARTY_PANEL_W, 2)

        if index > 1 then
            setColor({0.25, 0.15, 0.31, 1})
            love.graphics.rectangle("fill", x, STATUS_TOP, 1, panelH)
        end

        love.graphics.setFont(self.fonts.small)
        setColor(member.down and COLORS.red or member.color)
        love.graphics.print(member.name, x + 6, STATUS_TOP + 4)

        love.graphics.setFont(self.fonts.tiny)
        setColor(COLORS.white)
        love.graphics.print("HP", x + 6, STATUS_TOP + 19)
        love.graphics.print(tostring(member.hp), x + 24, STATUS_TOP + 19)
        setColor({0.55, 0.48, 0.62, 1})
        love.graphics.print("/" .. tostring(member.maxHp), x + 45, STATUS_TOP + 19)

        setColor({0.30, 0.02, 0.04, 1})
        love.graphics.rectangle("fill", x + 65, STATUS_TOP + 21, 23, 4)
        setColor(member.hp <= member.maxHp * 0.25 and COLORS.yellow or COLORS.green)
        love.graphics.rectangle("fill", x + 65, STATUS_TOP + 21, 23 * Util.clamp(member.hp / member.maxHp, 0, 1), 4)

        if self.state == "ACTIONSELECT" and index == self.currentSelecting then
            setColor(COLORS.white)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", x + 2, STATUS_TOP + 2, PARTY_PANEL_W - 4, panelH - 4)
        elseif self.state == "PARTYSELECT" and index == self.currentTarget then
            drawHeart(x + PARTY_PANEL_W - 10, STATUS_TOP + 10, 0.62, COLORS.red)
        elseif self:hasAction(index) then
            setColor(member.color)
            drawSpark(x + PARTY_PANEL_W - 9, STATUS_TOP + 9, 4)
        end
    end
end

function Battle:drawActionButtons()
    setColor(COLORS.black)
    love.graphics.rectangle("fill", 0, UI_TOP, TP_X, STATUS_TOP - UI_TOP)
    setColor({0.46, 0.05, 0.55, 1})
    love.graphics.rectangle("fill", 0, UI_TOP, TP_X, 2)

    if self.state == "ACTIONSELECT" then
        local member = self:getCurrentParty()
        local options = self:getActionOptions(member)
        self:drawCommandPortrait(member)

        for index, option in ipairs(options) do
            local x = PORTRAIT_W + (index - 1) * COMMAND_W
            local selected = index == self.currentButton
            local style = ACTION_STYLES[option] or {
                dark = shade(member.color, 0.25),
                bright = member.color,
            }

            setColor(selected and style.bright or style.dark)
            love.graphics.rectangle("fill", x, UI_TOP + 2, COMMAND_W, STATUS_TOP - UI_TOP - 2)

            if index > 1 then
                setColor({0.02, 0.01, 0.03, 0.90})
                love.graphics.rectangle("fill", x, UI_TOP + 2, 1, STATUS_TOP - UI_TOP - 2)
            end

            local iconColor = selected and COLORS.white or shade(style.bright, 0.92)
            drawActionIcon(option, x + COMMAND_W / 2, UI_TOP + 18, iconColor)

            love.graphics.setFont(self.fonts.tiny)
            setColor(selected and COLORS.white or shade(style.bright, 0.85))
            love.graphics.printf(option, x, UI_TOP + 31, COMMAND_W, "center")

            if selected then
                setColor(COLORS.white)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", x + 1, UI_TOP + 3, COMMAND_W - 2, STATUS_TOP - UI_TOP - 5)
                drawHeart(x + 7, UI_TOP + 8, 0.42, COLORS.red)
            end
        end

        setColor({0, 0, 0, 0.74})
        love.graphics.rectangle("fill", 0, UI_TOP - 17, TP_X, 16)
        love.graphics.setFont(self.fonts.tiny)
        setColor(COLORS.white)
        love.graphics.printf(self.encounterText, 7, UI_TOP - 14, TP_X - 14, "center")

    elseif self.state == "MENUSELECT" and self.currentMenu then
        love.graphics.setFont(self.fonts.small)
        for index, entry in ipairs(self.currentMenu.entries) do
            local column = (index - 1) % 2
            local row = math.floor((index - 1) / 2)
            local x = 20 + column * 136
            local y = UI_TOP + 7 + row * 15
            local unusable = entry.unusable or ((entry.tp or 0) > self.tension)

            if index == self.currentMenuIndex then
                drawHeart(x - 8, y + 5, 0.5, COLORS.red)
            end

            setColor(unusable and COLORS.gray or COLORS.white)
            love.graphics.print(entry.name, x, y)

            if entry.tp then
                love.graphics.setFont(self.fonts.tiny)
                setColor(unusable and COLORS.gray or COLORS.orange)
                love.graphics.print(tostring(entry.tp) .. "% TP", x + 79, y + 2)
                love.graphics.setFont(self.fonts.small)
            end
        end

    elseif self.state == "ENEMYSELECT" then
        love.graphics.setFont(self.fonts.normal)
        setColor(COLORS.white)
        love.graphics.print("* " .. self.enemy.name, 24, UI_TOP + 13)
        drawHeart(14, UI_TOP + 20, 0.55, COLORS.red)

    elseif self.state == "PARTYSELECT" then
        love.graphics.setFont(self.fonts.normal)
        setColor(COLORS.white)
        love.graphics.print("* Choose a party member.", 22, UI_TOP + 13)

    elseif self.state == "BATTLETEXT" then
        love.graphics.setFont(self.fonts.normal)
        setColor(COLORS.white)
        love.graphics.printf(self.textLines[self.textIndex] or "", 13, UI_TOP + 7, TP_X - 26, "left")

    elseif self.state == "ENEMYDIALOGUE" then
        love.graphics.setFont(self.fonts.normal)
        setColor(COLORS.white)
        love.graphics.printf("* The enemy prepares an attack...", 13, UI_TOP + 13, TP_X - 26, "left")

    elseif self.state == "DEFENDING" then
        love.graphics.setFont(self.fonts.small)
        setColor(COLORS.white)
        local target = self.party[self.targetedParty]
        love.graphics.printf("TARGET: " .. target.name .. "   Graze bullets to earn TP!", 8, UI_TOP + 15, TP_X - 16, "center")

    elseif self.state == "ATTACKING" then
        love.graphics.setFont(self.fonts.small)
        setColor(COLORS.white)
        love.graphics.printf("Press Z as each line reaches the center!", 8, UI_TOP + 15, TP_X - 16, "center")
    end
end

function Battle:drawArena()
    if self.state ~= "DEFENDING" then return end

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

    local x, y, w, h = 195, 24, 115, 37
    drawOutlinedRect(x, y, w, h, COLORS.white, COLORS.black, 1)
    setColor(COLORS.white)
    love.graphics.polygon("fill", x + 28, y + h, x + 36, y + h, x + 32, y + h + 7)
    setColor(COLORS.black)
    love.graphics.polygon("fill", x + 29, y + h - 1, x + 35, y + h - 1, x + 32, y + h + 5)

    love.graphics.setFont(self.fonts.small)
    love.graphics.printf(self.enemyDialogue, x + 5, y + 7, w - 10, "center")

    local position = BATTLE_POSITIONS[self.targetedParty]
    setColor(COLORS.red, 0.7 + math.sin(self.enemyDialogueTimer * 12) * 0.3)
    love.graphics.polygon(
        "fill",
        position[1], position[2] - 27,
        position[1] - 4, position[2] - 34,
        position[1] + 4, position[2] - 34
    )
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
    self:drawEnemyInfo()
    self:drawArena()
    self:drawAttackTiming()
    self:drawEnemyDialogue()
    self:drawActionButtons()
    self:drawStatusBoxes()
    self:drawTensionBar()
    self:drawResult()

    if self.state == "TRANSITIONOUT" then
        setColor({0, 0, 0, Util.clamp(self.outroTimer / 0.65, 0, 1)})
        love.graphics.rectangle("fill", 0, 0, SW, SH)
    end
end

return Battle
