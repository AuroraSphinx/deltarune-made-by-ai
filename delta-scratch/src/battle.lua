-- Battle glue for the Kristal engine with a Deltarune-style HUD.
--
-- Overrides the vendored renderer with the classic Chapter 1 look:
--   * bright green battle box with a white inner border
--   * party on the left (Kris front, Susie mid, Ralsei back), enemy right
--   * blue TP gauge bottom-left
--   * 2x2 yellow action buttons (FIGHT/ACT/ITEM/SPARE) bottom-right
--   * enemy name + HP + MERCY% top-left, party status stacked top-right
local Battle = require("vendor.kristal_legacy.battle")
local ctx = Battle._ctx
local Util = ctx.Util
local COLORS = ctx.COLORS
local setColor = ctx.setColor
local drawHeart = ctx.drawHeart

local SW, SH = 320, 240
local UI_TOP = ctx.UI_TOP
local STATUS_H = 19
local DIALOGUE_Y = UI_TOP + 1 + STATUS_H + 1 + 20 + 1
local DIALOGUE_H = SH - DIALOGUE_Y

local GREEN = {0.25, 1, 0.35, 1}      -- battle box green
local YELLOW = {1, 0.87, 0.12, 1}     -- action buttons
local TP_BLUE = {0.30, 0.60, 1, 1}    -- TP gauge
local PANEL_W = 96                    -- party status panel width

local originalDrawBackground = Battle.drawBackground
local originalDrawEnemyDialogue = Battle.drawEnemyDialogue
local originalDraw = Battle.draw

-- The vendored draw() does not call drawEnemyInfo (it was an empty stub), so
-- hook the enemy name/HP/MERCY panel in after the normal draw pass.
function Battle:draw()
    originalDraw(self)
    if self.active then
        self:drawEnemyInfo()
    end
end


function Battle:drawEnemyInfo()
    if self.state == "ATTACKING" or self.state == "TRANSITION" or self.state == "RESULT" then
        return
    end
    local x = 8
    local y = 5
    love.graphics.setFont(self.fonts.small)
    setColor(COLORS.white)
    love.graphics.print(self.enemy.name, x, y)
    local barX = x
    local barY = y + 14
    local barW = 92
    local barH = 5
    setColor({0.18, 0.18, 0.24, 1})
    love.graphics.rectangle("fill", barX, barY, barW, barH)
    setColor(COLORS.white)
    love.graphics.rectangle("fill", barX, barY, barW * Util.clamp(self.enemy.hp / self.enemy.maxHp, 0, 1), barH)
    setColor(COLORS.white)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX - 1, barY - 1, barW + 2, barH + 2)
    if self.enemy.mercy > 0 then
        setColor(self.enemy.mercy >= 100 and COLORS.yellow or COLORS.orange)
        love.graphics.setFont(self.fonts.tiny)
        love.graphics.print("MERCY " .. self.enemy.mercy .. "%", barX + barW + 6, barY)
    end
end

-- ---------------------------------------------------------------------------
-- Background (chapter backdrop image + dark overlay)
-- ---------------------------------------------------------------------------
function Battle:drawBackground()
    if not self.assets or not self.assets:has("battle_background") then
        return originalDrawBackground(self)
    end

    local alpha = self.state == "TRANSITION" and self.transitionTimer or 1
    love.graphics.clear(0, 0, 0, 1)
    self.assets:drawCover("battle_background", 0, 0, ctx.SW, UI_TOP, {alpha = alpha})

    -- Keep the extracted background readable behind bullets and status text.
    love.graphics.setColor(0, 0, 0, 0.24)
    love.graphics.rectangle("fill", 0, 0, ctx.SW, UI_TOP)
    love.graphics.setColor(0.35, 0.28, 0.38, 1)
    love.graphics.rectangle("fill", 4, UI_TOP - 1, ctx.SW - 8, 1)
end

-- ---------------------------------------------------------------------------
-- Party: animated battle sprites, Deltarune positions (feet on the ground)
-- ---------------------------------------------------------------------------
local function getPartyPositions(count)
    if count <= 1 then
        return {{64, 110}}
    elseif count == 2 then
        return {{62, 114}, {118, 98}}
    end
    -- Kris front-left, Susie mid, Ralsei furthest back.
    return {{58, 118}, {104, 100}, {152, 84}}
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

    local sprite = "hero_battle"
    if member.id == "susie" then
        sprite = "friend_battle"
    elseif member.id == "ralsei" then
        sprite = "ralsei"
    end

    self.assets:draw(sprite, x, y + bob, {
        centered = true,
        animTime = member.animationTimer,
    })

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

    local enemyX = 250 + (1 - transitionAmount) * 105
    local enemyY = 92 + math.sin(self.enemy.animationTimer * 2.8) * 2

    if not self.enemy.defeated then
        local animation = self.enemy.spared and "spared" or "idle"
        self.assets:draw("enemy", enemyX, enemyY, {
            centered = true,
            animation = animation,
            animTime = self.enemy.animationTimer,
        })

        if self.enemy.tired and not self.enemy.spared then
            love.graphics.setFont(self.fonts.small)
            setColor(COLORS.blue)
            love.graphics.print("Z", enemyX + 15, enemyY - 27)
            love.graphics.print("z", enemyX + 22, enemyY - 34)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Battle box: bright green border + white inner border + dark fill
-- ---------------------------------------------------------------------------
function Battle:drawArena()
    if self.state ~= "DEFENDING" then
        return
    end

    local a = self.arena

    -- Interior so white bullets read on any backdrop.
    setColor({0, 0, 0, 0.5})
    love.graphics.rectangle("fill", a.x, a.y, a.w, a.h)

    -- White inner border, then the signature green outer border.
    setColor(COLORS.white)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", a.x + 2, a.y + 2, a.w - 4, a.h - 4)
    setColor(GREEN)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", a.x, a.y, a.w, a.h)

    for _, bullet in ipairs(self.bullets) do
        setColor(bullet.grazed and COLORS.aqua or COLORS.white)
        love.graphics.rectangle("fill", bullet.x, bullet.y, bullet.w, bullet.h)
    end

    if self.soul.invulnerability <= 0 or math.floor(self.soul.invulnerability * 15) % 2 == 0 then
        drawHeart(self.soul.x + self.soul.w / 2, self.soul.y + self.soul.h / 2, 0.75, COLORS.red)
    end
end

-- ---------------------------------------------------------------------------
-- TP gauge: blue bar, bottom-left (Deltarune style)
-- ---------------------------------------------------------------------------
function Battle:drawTensionBar()
    local labelX = 6
    local barX = 24
    local barY = SH - 17
    local barW = 44
    local barH = 8

    love.graphics.setFont(self.fonts.tiny)
    setColor(COLORS.white)
    love.graphics.print("TP", labelX, barY - 2)

    setColor({0.05, 0.12, 0.30, 1})
    love.graphics.rectangle("fill", barX, barY, barW, barH)
    setColor(COLORS.white)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX, barY, barW, barH)

    local ratio = Util.clamp(self.tension / self.maxTension, 0, 1)
    if ratio > 0 then
        setColor(TP_BLUE)
        love.graphics.rectangle("fill", barX + 1, barY + 1, math.floor((barW - 2) * ratio), barH - 2)
    end

    love.graphics.setFont(self.fonts.small)
    setColor(COLORS.white)
    love.graphics.print(tostring(math.floor(self.tension)), barX + barW + 6, barY - 3)
end

-- ---------------------------------------------------------------------------
-- Party status: stacked panels in the top-right corner
-- ---------------------------------------------------------------------------
function Battle:drawStatusBoxes()
    if self.state == "ATTACKING" then
        return
    end

    local count = #self.party
    local gap = 3
    local x = SW - PANEL_W - 4

    for index, member in ipairs(self.party) do
        local y = 4 + (index - 1) * (STATUS_H + gap)
        local selected = self.state == "ACTIONSELECT" and index == self.currentSelecting
        self:drawOneStatusPanel(member, index, x, y, PANEL_W, selected)
    end
end

-- ---------------------------------------------------------------------------
-- Enemy info: name + HP + MERCY% in the top-left corner
-- ---------------------------------------------------------------------------
function Battle:drawEnemyInfo()
    if self.state == "ATTACKING" or self.state == "TRANSITION" or self.state == "RESULT" then
        return
    end

    local x = 8
    local y = 5

    love.graphics.setFont(self.fonts.small)
    setColor(COLORS.white)
    love.graphics.print(self.enemy.name, x, y)

    local barX = x
    local barY = y + 14
    local barW = 92
    local barH = 5

    setColor(0.18, 0.18, 0.24, 1)
    love.graphics.rectangle("fill", barX, barY, barW, barH)
    setColor(COLORS.white)
    love.graphics.rectangle("fill", barX, barY, barW * Util.clamp(self.enemy.hp / self.enemy.maxHp, 0, 1), barH)
    setColor(COLORS.white)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX - 1, barY - 1, barW + 2, barH + 2)

    if self.enemy.mercy > 0 then
        setColor(self.enemy.mercy >= 100 and COLORS.yellow or COLORS.orange)
        love.graphics.setFont(self.fonts.tiny)
        love.graphics.print("MERCY " .. self.enemy.mercy .. "%", barX + barW + 6, barY)
    end
end

-- ---------------------------------------------------------------------------
-- Action buttons: 2x2 yellow grid, bottom-right (FIGHT/ACT / ITEM/SPARE)
-- ---------------------------------------------------------------------------
function Battle:drawCommandButtons()
    if self.state ~= "ACTIONSELECT" then
        return
    end

    local member = self:getCurrentParty()
    if not member then
        return
    end

    local options = self:getActionOptions(member)
    local buttonW = 34
    local buttonH = 20
    local gap = 3
    local columns = 2
    local rows = math.ceil(#options / columns)
    local gridW = columns * buttonW + (columns - 1) * gap
    local gridH = rows * buttonH + (rows - 1) * gap
    local gridX = SW - gridW - 5
    local gridY = SH - gridH - 4

    love.graphics.setFont(self.fonts.tiny)
    for index, option in ipairs(options) do
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        local x = gridX + column * (buttonW + gap)
        local y = gridY + row * (buttonH + gap)
        local selected = index == self.currentButton

        if selected then
            setColor(YELLOW)
            love.graphics.rectangle("fill", x, y, buttonW, buttonH)
            setColor(COLORS.black)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", x, y, buttonW, buttonH)
            love.graphics.printf(option, x, y + buttonH / 2 - 5, buttonW, "center")
        else
            setColor(COLORS.black)
            love.graphics.rectangle("fill", x, y, buttonW, buttonH)
            setColor(YELLOW)
            love.graphics.rectangle("line", x, y, buttonW, buttonH)
            setColor({1, 0.93, 0.35, 1})
            love.graphics.printf(option, x, y + buttonH / 2 - 5, buttonW, "center")
        end
    end
end

-- ---------------------------------------------------------------------------
-- Dialogue box: white-bordered, text kept left of the action buttons
-- ---------------------------------------------------------------------------
function Battle:drawDialogueBox()
    if self.state == "ATTACKING" then
        return
    end

    setColor(COLORS.black)
    love.graphics.rectangle("fill", 0, DIALOGUE_Y, SW, DIALOGUE_H)
    setColor(COLORS.white)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", 2, DIALOGUE_Y, SW - 4, DIALOGUE_H)

    local textW = SW - 132 -- leave room for the 2x2 buttons

    if self.state == "ACTIONSELECT" then
        love.graphics.setFont(self.fonts.normal)
        setColor(COLORS.white)
        love.graphics.printf(self.encounterText, 17, DIALOGUE_Y + 9, textW, "left")

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
        love.graphics.printf(self.textLines[self.textIndex] or "", 17, DIALOGUE_Y + 7, textW, "left")

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
            textW,
            "center"
        )
    end
end

-- Enemy speech bubble: sits right of the (bigger) battle box.
function Battle:drawEnemyDialogue()
    if self.state ~= "ENEMYDIALOGUE" or not self.enemyDialogue then
        return
    end

    local x, y, w, h = 214, 22, 100, 34
    setColor(COLORS.white)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    setColor(COLORS.black)
    love.graphics.rectangle("fill", x + 1, y + 1, w - 2, h - 2)
    love.graphics.polygon("fill", x + 27, y + h, x + 35, y + h, x + 31, y + h + 7)

    love.graphics.setFont(self.fonts.small)
    setColor(COLORS.white)
    love.graphics.printf(self.enemyDialogue, x + 5, y + 7, w - 10, "center")
end

return Battle
