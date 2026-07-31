--[[
Kristal legacy battle-system port for the standalone LÖVE project.

Substantial state-machine, action-queue, targeting, wave, TP, and battle-flow
structure is ported from Kristal commit:
  d3f87dad18bc5c1fdce0ecd90511a5ff55476ce7

Upstream project: https://github.com/KristalTeam/Kristal
Upstream license: BSD-3-Clause (see LICENSE in this directory)

This file adapts the upstream engine code to the repository's existing API:
    Battle.new(assets, fonts)
    battle:start(onExit)
    battle:update(dt)
    battle:keypressed(key)
    battle:draw()

The surrounding overworld, title state, canvas, and asset loader remain the
standalone project's own code.
]]

local Util = require("src.util")

local Battle = {}
Battle.__index = Battle

local SW, SH = 320, 240
local UI_TOP = 162
local STATUS_TOP = 203
local ARENA_DEFAULT = {x = 94, y = 75, w = 132, h = 65}

local COLORS = {
    white = {1, 1, 1, 1},
    black = {0, 0, 0, 1},
    gray = {0.45, 0.45, 0.50, 1},
    darkgray = {0.13, 0.13, 0.17, 1},
    red = {1, 0.12, 0.12, 1},
    orange = {1, 0.63, 0.25, 1},
    yellow = {1, 1, 0.10, 1},
    green = {0.25, 1, 0.35, 1},
    aqua = {0.25, 0.95, 1, 1},
    blue = {0.20, 0.45, 1, 1},
    purple = {0.62, 0.26, 0.82, 1},
    pink = {1, 0.36, 0.72, 1},
}

local PARTY_DEFS = {
    {
        id = "kris",
        name = "KRIS",
        color = {0.25, 0.72, 1, 1},
        hp = 90,
        maxHp = 90,
        attack = 12,
        defense = 2,
        actions = {"FIGHT", "ACT", "ITEM", "SPARE", "DEFEND"},
    },
    {
        id = "susie",
        name = "SUSIE",
        color = {0.95, 0.35, 0.85, 1},
        hp = 110,
        maxHp = 110,
        attack = 16,
        defense = 1,
        actions = {"FIGHT", "MAGIC", "ITEM", "SPARE", "DEFEND"},
    },
    {
        id = "ralsei",
        name = "RALSEI",
        color = {0.35, 1, 0.55, 1},
        hp = 70,
        maxHp = 70,
        attack = 8,
        defense = 3,
        actions = {"FIGHT", "MAGIC", "ITEM", "SPARE", "DEFEND"},
    },
}

local function copyTable(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do
        result[key] = copyTable(child)
    end
    return result
end

local function isConfirm(key)
    return key == "z" or key == "return" or key == "space"
end

local function isCancel(key)
    return key == "x" or key == "escape"
end

local function wrap(index, count)
    if count <= 0 then return 1 end
    return ((index - 1) % count) + 1
end

local function rectsOverlap(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w
       and a.y < b.y + b.h and b.y < a.y + a.h
end

local function distanceToRect(px, py, rect)
    local cx = Util.clamp(px, rect.x, rect.x + rect.w)
    local cy = Util.clamp(py, rect.y, rect.y + rect.h)
    local dx, dy = px - cx, py - cy
    return math.sqrt(dx * dx + dy * dy)
end

local function setColor(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

local function drawHeart(x, y, scale, color)
    scale = scale or 1
    setColor(color or COLORS.red)
    love.graphics.polygon(
        "fill",
        x, y + 3 * scale,
        x - 4 * scale, y - 1 * scale,
        x - 3 * scale, y - 4 * scale,
        x, y - 2 * scale,
        x + 3 * scale, y - 4 * scale,
        x + 4 * scale, y - 1 * scale
    )
end

local function drawOutlinedRect(x, y, w, h, fill, outline, lineWidth)
    setColor(fill or COLORS.black)
    love.graphics.rectangle("fill", x, y, w, h)
    setColor(outline or COLORS.white)
    love.graphics.setLineWidth(lineWidth or 1)
    love.graphics.rectangle("line", x, y, w, h)
end

local function makeParty()
    local party = {}
    for index, definition in ipairs(PARTY_DEFS) do
        local member = copyTable(definition)
        member.index = index
        member.defending = false
        member.down = false
        member.flash = 0
        member.animation = "idle"
        member.animationTimer = 0
        party[index] = member
    end
    return party
end

function Battle.new(assets, fonts)
    local self = setmetatable({}, Battle)
    self.assets = assets
    self.fonts = fonts
    self.active = false
    self.state = "NONE"
    self.substate = "NONE"
    self.stateReason = nil
    self.substateReason = nil
    self.onExit = nil
    self.party = makeParty()
    self.enemy = nil
    self.turnCount = 0
    self.currentSelecting = 1
    self.currentButton = 1
    self.currentMenu = nil
    self.currentMenuIndex = 1
    self.currentTarget = 1
    self.selectedSpell = nil
    self.selectedItem = nil
    self.selectedAct = nil
    self.characterActions = {}
    self.selectedActionStack = {}
    self.selectedCharacterStack = {}
    self.currentActions = {}
    self.currentActionIndex = 1
    self.processingAction = false
    self.actionDelay = 0
    self.textLines = {}
    self.textIndex = 1
    self.textCallback = nil
    self.textAutoTimer = nil
    self.encounterText = ""
    self.transitionTimer = 0
    self.introTimer = 0
    self.outroTimer = 0
    self.backgroundOffset = 0
    self.tension = 0
    self.maxTension = 100
    self.tensionFlash = 0
    self.items = {darkburger = 2}
    self.arena = copyTable(ARENA_DEFAULT)
    self.soul = nil
    self.bullets = {}
    self.waveTimer = 0
    self.waveLength = 0
    self.spawnTimer = 0
    self.wavePattern = 1
    self.targetedParty = 1
    self.enemyDialogue = nil
    self.enemyDialogueTimer = 0
    self.attackers = {}
    self.attackLanes = {}
    self.attackLaneIndex = 1
    self.attackResultTimer = 0
    self.result = nil
    self.resultTimer = 0
    return self
end

-- Ported form of Kristal's Battle:setState.
function Battle:setState(state, reason)
    local old = self.state
    self.state = state
    self.stateReason = reason
    self:onStateChange(old, state, reason)
end

-- Ported form of Kristal's Battle:setSubState.
function Battle:setSubState(state, reason)
    local old = self.substate
    self.substate = state
    self.substateReason = reason
    self:onSubStateChange(old, state, reason)
end

function Battle:getState()
    return self.state
end

function Battle:getSubState()
    return self.substate
end

function Battle:start(onExit)
    self.active = true
    self.onExit = onExit
    self.party = makeParty()
    self.enemy = {
        id = "training_dummy",
        name = "RUDINN TESTER",
        hp = 420,
        maxHp = 420,
        attack = 6,
        defense = 2,
        mercy = 0,
        tired = false,
        spared = false,
        defeated = false,
        animation = "idle",
        animationTimer = 0,
    }
    self.turnCount = 0
    self.currentSelecting = 1
    self.currentButton = 1
    self.currentMenu = nil
    self.currentMenuIndex = 1
    self.currentTarget = 1
    self.characterActions = {}
    self.selectedActionStack = {}
    self.selectedCharacterStack = {}
    self.currentActions = {}
    self.currentActionIndex = 1
    self.processingAction = false
    self.actionDelay = 0
    self.textLines = {}
    self.textIndex = 1
    self.textCallback = nil
    self.textAutoTimer = nil
    self.encounterText = "* A training enemy blocks the way."
    self.transitionTimer = 0
    self.introTimer = 0
    self.outroTimer = 0
    self.backgroundOffset = 0
    self.tension = 0
    self.tensionFlash = 0
    self.items = {darkburger = 2}
    self.arena = copyTable(ARENA_DEFAULT)
    self.soul = nil
    self.bullets = {}
    self.waveTimer = 0
    self.waveLength = 0
    self.spawnTimer = 0
    self.wavePattern = 1
    self.targetedParty = 1
    self.enemyDialogue = nil
    self.enemyDialogueTimer = 0
    self.attackers = {}
    self.attackLanes = {}
    self.attackLaneIndex = 1
    self.result = nil
    self.resultTimer = 0
    self:setSubState("NONE")
    self:setState("TRANSITION")
end

function Battle:exit()
    self.active = false
    local callback = self.onExit
    self.onExit = nil
    if callback then callback() end
end

function Battle:onSubStateChange(old, new)
    if old == "ACT" and new ~= "ACT" then
        for _, member in ipairs(self.party) do
            if member.animation == "act" then
                member.animation = "idle"
            end
        end
    end
end

-- This state list and state flow are ported from Kristal's legacy Battle.
function Battle:onStateChange(old, new, reason)
    if new == "TRANSITION" then
        self.transitionTimer = 0
        for _, member in ipairs(self.party) do
            member.animation = "transition"
        end

    elseif new == "INTRO" then
        self.introTimer = 0
        for _, member in ipairs(self.party) do
            member.animation = "intro"
        end

    elseif new == "ACTIONSELECT" then
        self.turnCount = self.turnCount + 1
        self.currentSelecting = 1
        self.currentButton = 1
        self.currentMenu = nil
        self.currentMenuIndex = 1
        self.characterActions = {}
        self.selectedActionStack = {}
        self.selectedCharacterStack = {}
        self.currentActions = {}
        self.currentActionIndex = 1
        self.processingAction = false
        self.attackers = {}
        self.attackLanes = {}
        self.bullets = {}
        self.soul = nil
        self.enemyDialogue = nil
        for _, member in ipairs(self.party) do
            member.defending = false
            if member.hp > 0 then
                member.animation = "idle"
            end
        end
        if self.enemy.mercy >= 100 then
            self.encounterText = "* " .. self.enemy.name .. " can be SPARED!"
        elseif self.enemy.tired then
            self.encounterText = "* " .. self.enemy.name .. " is TIRED."
        else
            local messages = {
                "* The enemy tests its polygon count.",
                "* The air crackles with debug energy.",
                "* Smells like a proper party battle.",
            }
            self.encounterText = messages[((self.turnCount - 1) % #messages) + 1]
        end

    elseif new == "MENUSELECT" then
        self.currentMenuIndex = 1

    elseif new == "ENEMYSELECT" then
        self.currentTarget = 1

    elseif new == "PARTYSELECT" then
        self.currentTarget = self:firstLivingPartyIndex()

    elseif new == "ACTIONS" then
        self.currentActions = {}
        for _, action in ipairs(self.characterActions) do
            table.insert(self.currentActions, action)
        end
        self.currentActionIndex = 1
        self.processingAction = false
        self.actionDelay = 0.12
        self:tryProcessNextAction()

    elseif new == "ATTACKING" then
        self.attackLaneIndex = 1
        self.attackResultTimer = 0
        for laneIndex, action in ipairs(self.attackers) do
            self.attackLanes[laneIndex] = {
                action = action,
                position = -0.08 - (laneIndex - 1) * 0.13,
                speed = 0.95 + laneIndex * 0.06,
                stopped = false,
                accuracy = 0,
                damage = 0,
            }
        end

    elseif new == "ENEMYDIALOGUE" then
        self.enemyDialogueTimer = 0
        self.targetedParty = self:pickEnemyTarget()
        self.enemyDialogue = self.enemy.tired and "... zzz ..." or ({
            "Prepare yourself!",
            "This is a REAL wave!",
            "Try grazing this!",
        })[((self.turnCount - 1) % 3) + 1]

    elseif new == "DIALOGUEEND" then
        self:startDefending()

    elseif new == "DEFENDING" then
        self.waveTimer = 0
        self.waveLength = 5.5
        self.spawnTimer = 0
        self.wavePattern = ((self.turnCount - 1) % 3) + 1
        self.bullets = {}
        self.soul = {
            x = self.arena.x + self.arena.w / 2 - 3,
            y = self.arena.y + self.arena.h / 2 - 3,
            w = 6,
            h = 6,
            speed = 92,
            invulnerability = 0,
        }

    elseif new == "VICTORY" then
        for _, member in ipairs(self.party) do
            if member.hp > 0 then member.animation = "victory" end
        end
        self:showText({
            "* You won!",
            self.enemy.spared and "* The enemy was spared.\n* Recruits increased!" or "* Got 0 EXP and 48 D$."
        }, function()
            self:setState("TRANSITIONOUT")
        end)

    elseif new == "TRANSITIONOUT" then
        self.outroTimer = 0

    elseif new == "RESULT" then
        self.resultTimer = 0
    end
end


Battle._ctx = {
    Util = Util,
    SW = SW,
    SH = SH,
    UI_TOP = UI_TOP,
    STATUS_TOP = STATUS_TOP,
    ARENA_DEFAULT = ARENA_DEFAULT,
    COLORS = COLORS,
    copyTable = copyTable,
    isConfirm = isConfirm,
    isCancel = isCancel,
    wrap = wrap,
    rectsOverlap = rectsOverlap,
    distanceToRect = distanceToRect,
    setColor = setColor,
    drawHeart = drawHeart,
    drawOutlinedRect = drawOutlinedRect,
    makeParty = makeParty,
}

return Battle
