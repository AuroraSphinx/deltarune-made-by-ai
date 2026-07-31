-- Action queue and target/menu processing ported from Kristal legacy.
local Battle = require("vendor.kristal_legacy.battle_base")
local Util = Battle._ctx.Util

function Battle:firstLivingPartyIndex()
    for index, member in ipairs(self.party) do
        if member.hp > 0 then return index end
    end
    return 1
end

function Battle:pickEnemyTarget()
    local living = {}
    for index, member in ipairs(self.party) do
        if member.hp > 0 then table.insert(living, index) end
    end
    if #living == 0 then return 1 end
    return living[((self.turnCount - 1) % #living) + 1]
end

function Battle:getCurrentParty()
    return self.party[self.currentSelecting]
end

function Battle:hasAction(characterIndex)
    for _, action in ipairs(self.characterActions) do
        if action.character_id == characterIndex then return true end
    end
    return false
end

-- Directly follows Kristal's legacy action-stack design.
function Battle:pushAction(actionType, target, data)
    local action = {
        character_id = self.currentSelecting,
        action = actionType,
        target = target,
        data = data,
    }
    table.insert(self.characterActions, action)
    table.insert(self.selectedCharacterStack, self.currentSelecting)
    table.insert(self.selectedActionStack, action)
    self:nextParty()
    return action
end

function Battle:removeAction(characterIndex)
    for index = #self.characterActions, 1, -1 do
        if self.characterActions[index].character_id == characterIndex then
            table.remove(self.characterActions, index)
            return
        end
    end
end

function Battle:nextParty()
    self.currentSelecting = self.currentSelecting + 1
    while self.currentSelecting <= #self.party
      and (self.party[self.currentSelecting].hp <= 0 or self:hasAction(self.currentSelecting)) do
        self.currentSelecting = self.currentSelecting + 1
    end

    if self.currentSelecting > #self.party then
        self.currentSelecting = 0
        self:setState("ACTIONS")
    else
        self.currentButton = 1
        self.currentMenu = nil
        self:setState("ACTIONSELECT", "NEXT")
        -- ACTIONSELECT normally resets a turn, so restore queued state when moving
        -- between party members. This is the standalone adapter's only deviation.
        self.turnCount = self.turnCount - 1
        self.currentSelecting = self.selectedCharacterStack[#self.selectedCharacterStack] + 1
        while self.currentSelecting <= #self.party and self.party[self.currentSelecting].hp <= 0 do
            self.currentSelecting = self.currentSelecting + 1
        end
        self.characterActions = {}
        for _, action in ipairs(self.selectedActionStack) do
            table.insert(self.characterActions, action)
        end
        self.selectedCharacterStack = {}
        for _, action in ipairs(self.characterActions) do
            table.insert(self.selectedCharacterStack, action.character_id)
        end
        self.currentButton = 1
    end
end

-- Safer replacement for the adapter-specific nextParty reset above.
function Battle:advanceParty()
    local nextIndex = self.currentSelecting + 1
    while nextIndex <= #self.party and (self.party[nextIndex].hp <= 0 or self:hasAction(nextIndex)) do
        nextIndex = nextIndex + 1
    end
    if nextIndex > #self.party then
        self.currentSelecting = 0
        self:setState("ACTIONS")
    else
        self.currentSelecting = nextIndex
        self.currentButton = 1
        self.currentMenu = nil
        self.currentMenuIndex = 1
        self.state = "ACTIONSELECT"
        self.stateReason = "NEXT"
    end
end

-- Override pushAction to use the adapter-safe advance while retaining Kristal's
-- action record and stack shape.
function Battle:queueAction(actionType, target, data)
    local action = {
        character_id = self.currentSelecting,
        action = actionType,
        target = target,
        data = data,
    }
    table.insert(self.characterActions, action)
    table.insert(self.selectedCharacterStack, self.currentSelecting)
    table.insert(self.selectedActionStack, action)
    self:advanceParty()
    return action
end

function Battle:cancelCurrentSelection()
    if self.currentMenu then
        self.currentMenu = nil
        self.currentMenuIndex = 1
        self.state = "ACTIONSELECT"
        return
    end
    if self.state == "ENEMYSELECT" or self.state == "PARTYSELECT" then
        self.state = "ACTIONSELECT"
        return
    end
    if self.state ~= "ACTIONSELECT" then return end
    local lastAction = table.remove(self.selectedActionStack)
    local lastCharacter = table.remove(self.selectedCharacterStack)
    if lastAction and lastCharacter then
        self:removeAction(lastCharacter)
        self.currentSelecting = lastCharacter
        self.currentButton = 1
    end
end

function Battle:getActionOptions(member)
    return member.actions
end

function Battle:selectActionButton()
    local member = self:getCurrentParty()
    if not member then return end
    local options = self:getActionOptions(member)
    local selected = options[self.currentButton]

    if selected == "FIGHT" then
        self:setState("ENEMYSELECT", "ATTACK")
    elseif selected == "ACT" then
        self:setState("ENEMYSELECT", "ACT")
    elseif selected == "MAGIC" then
        self:openMagicMenu(member)
    elseif selected == "ITEM" then
        self:openItemMenu()
    elseif selected == "SPARE" then
        self:setState("ENEMYSELECT", "SPARE")
    elseif selected == "DEFEND" then
        self:queueAction("DEFEND", nil, {tp = 16})
    end
end

function Battle:openActMenu()
    self.currentMenu = {
        kind = "ACT",
        entries = {
            {name = "Check", description = "Check enemy stats."},
            {name = "Compliment", description = "Raise MERCY."},
            {name = "Lecture", description = "Make the enemy TIRED."},
        }
    }
    self:setState("MENUSELECT", "ACT")
end

function Battle:openMagicMenu(member)
    local entries
    if member.id == "susie" then
        entries = {
            {name = "Rude Buster", tp = 50, kind = "DAMAGE", target = "enemy", description = "Deals rude damage."},
        }
    else
        entries = {
            {name = "Heal Prayer", tp = 32, kind = "HEAL", target = "party", description = "Heals one ally."},
            {name = "Pacify", tp = 16, kind = "PACIFY", target = "enemy", description = "Spares a TIRED foe."},
        }
    end
    self.currentMenu = {kind = "MAGIC", entries = entries}
    self:setState("MENUSELECT", "MAGIC")
end

function Battle:openItemMenu()
    local entries = {}
    if self.items.darkburger > 0 then
        table.insert(entries, {
            name = "Darkburger x" .. self.items.darkburger,
            kind = "HEAL",
            amount = 70,
            target = "party",
            description = "Heals 70 HP."
        })
    end
    if #entries == 0 then
        table.insert(entries, {name = "(EMPTY)", unusable = true, description = "No items."})
    end
    self.currentMenu = {kind = "ITEM", entries = entries}
    self:setState("MENUSELECT", "ITEM")
end

function Battle:selectEnemy()
    local reason = self.stateReason
    if reason == "ATTACK" then
        self:queueAction("ATTACK", self.enemy)
    elseif reason == "ACT" then
        self:openActMenu()
    elseif reason == "SPARE" then
        self:queueAction("SPARE", self.enemy)
    elseif reason == "SPELL" then
        local spell = self.selectedSpell
        self.selectedSpell = nil
        self:queueAction("SPELL", self.enemy, spell)
    end
end

function Battle:selectPartyTarget()
    local target = self.party[self.currentTarget]
    if not target or target.hp <= 0 then return end
    if self.stateReason == "SPELL" then
        local spell = self.selectedSpell
        self.selectedSpell = nil
        self:queueAction("SPELL", target, spell)
    elseif self.stateReason == "ITEM" then
        local item = self.selectedItem
        self.selectedItem = nil
        self:queueAction("ITEM", target, item)
    end
end

function Battle:selectMenuEntry()
    if not self.currentMenu then return end
    local entry = self.currentMenu.entries[self.currentMenuIndex]
    if not entry or entry.unusable then return end

    if self.currentMenu.kind == "ACT" then
        self.currentMenu = nil
        self:queueAction("ACT", self.enemy, entry)
    elseif self.currentMenu.kind == "MAGIC" then
        if (entry.tp or 0) > self.tension then
            self.tensionFlash = 0.45
            return
        end
        self.currentMenu = nil
        self.selectedSpell = entry
        if entry.target == "party" then
            self:setState("PARTYSELECT", "SPELL")
        else
            self:setState("ENEMYSELECT", "SPELL")
        end
    elseif self.currentMenu.kind == "ITEM" then
        self.currentMenu = nil
        self.selectedItem = entry
        self:setState("PARTYSELECT", "ITEM")
    end
end

function Battle:showText(lines, callback, autoTime)
    if type(lines) == "string" then lines = {lines} end
    self.textLines = lines
    self.textIndex = 1
    self.textCallback = callback
    self.textAutoTimer = autoTime
    self:setState("BATTLETEXT")
end

function Battle:advanceText()
    if self.textIndex < #self.textLines then
        self.textIndex = self.textIndex + 1
        self.textAutoTimer = nil
        return
    end
    local callback = self.textCallback
    self.textLines = {}
    self.textIndex = 1
    self.textCallback = nil
    self.textAutoTimer = nil
    if callback then callback() end
end

function Battle:beginAction(action)
    local member = self.party[action.character_id]
    if member and member.hp > 0 then
        member.animation = string.lower(action.action)
        member.animationTimer = 0
    end
end

function Battle:finishAction(action)
    local member = self.party[action.character_id]
    if member and member.hp > 0 then
        member.animation = "idle"
    end
    self.processingAction = false
    self.currentActionIndex = self.currentActionIndex + 1
    self.actionDelay = 0.10
end

-- Ported action-queue processing shape from Kristal's legacy Battle.
function Battle:tryProcessNextAction()
    if self.processingAction or self.state ~= "ACTIONS" then return end
    if self.currentActionIndex > #self.currentActions then
        if #self.attackers > 0 then
            self:setState("ATTACKING")
        else
            self:setState("ENEMYDIALOGUE")
        end
        return
    end

    local action = self.currentActions[self.currentActionIndex]
    self.processingAction = true
    self:beginAction(action)
    self:processAction(action)
end

function Battle:processAction(action)
    local member = self.party[action.character_id]
    local enemy = action.target == self.enemy and self.enemy or self.enemy

    if not member or member.hp <= 0 then
        self:finishAction(action)
        return
    end

    if action.action == "DEFEND" then
        member.defending = true
        self:addTension(action.data and action.data.tp or 16)
        self:finishAction(action)

    elseif action.action == "ATTACK" then
        table.insert(self.attackers, action)
        self:finishAction(action)

    elseif action.action == "SPARE" then
        if enemy.mercy >= 100 then
            enemy.spared = true
            self:showText("* " .. member.name .. " spared " .. enemy.name .. "!", function()
                self:finishAction(action)
                self:setState("VICTORY")
            end)
        else
            self:showText("* " .. member.name .. " tried to SPARE...\n* But its name wasn't yellow.", function()
                self:finishAction(action)
                self.state = "ACTIONS"
                self:tryProcessNextAction()
            end)
        end

    elseif action.action == "ACT" then
        self:setSubState("ACT")
        local name = action.data.name
        if name == "Check" then
            self:showText("* " .. enemy.name .. " - AT " .. enemy.attack .. " DF " .. enemy.defense .. "\n* A tester that finally uses party turns.", function()
                self:setSubState("NONE")
                self:finishAction(action)
                self.state = "ACTIONS"
                self:tryProcessNextAction()
            end)
        elseif name == "Compliment" then
            enemy.mercy = Util.clamp(enemy.mercy + 50, 0, 100)
            self:showText("* Kris complimented the enemy's battle UI.\n* MERCY increased!", function()
                self:setSubState("NONE")
                self:finishAction(action)
                self.state = "ACTIONS"
                self:tryProcessNextAction()
            end)
        elseif name == "Lecture" then
            enemy.tired = true
            enemy.mercy = Util.clamp(enemy.mercy + 25, 0, 100)
            self:showText("* Kris explained why solo Undertale menus were wrong.\n* The enemy became TIRED.", function()
                self:setSubState("NONE")
                self:finishAction(action)
                self.state = "ACTIONS"
                self:tryProcessNextAction()
            end)
        end

    elseif action.action == "SPELL" then
        local spell = action.data
        self:removeTension(spell.tp or 0)
        if spell.kind == "DAMAGE" then
            local damage = math.max(1, member.attack * 5 - enemy.defense * 3)
            enemy.hp = math.max(0, enemy.hp - damage)
            self:showText("* Susie cast RUDE BUSTER!\n* " .. damage .. " damage!", function()
                self:finishAction(action)
                if enemy.hp <= 0 then
                    enemy.defeated = true
                    self:setState("VICTORY")
                else
                    self.state = "ACTIONS"
                    self:tryProcessNextAction()
                end
            end)
        elseif spell.kind == "HEAL" then
            local target = action.target
            local amount = 55
            target.hp = math.min(target.maxHp, target.hp + amount)
            target.down = false
            self:showText("* Ralsei cast HEAL PRAYER!\n* " .. target.name .. " recovered " .. amount .. " HP.", function()
                self:finishAction(action)
                self.state = "ACTIONS"
                self:tryProcessNextAction()
            end)
        elseif spell.kind == "PACIFY" then
            if enemy.tired then
                enemy.spared = true
                self:showText("* Ralsei cast PACIFY!\n* " .. enemy.name .. " fell asleep.", function()
                    self:finishAction(action)
                    self:setState("VICTORY")
                end)
            else
                self:showText("* Ralsei cast PACIFY...\n* The enemy wasn't TIRED.", function()
                    self:finishAction(action)
                    self.state = "ACTIONS"
                    self:tryProcessNextAction()
                end)
            end
        end

    elseif action.action == "ITEM" then
        local target = action.target
        local amount = action.data.amount or 70
        target.hp = math.min(target.maxHp, target.hp + amount)
        target.down = false
        self.items.darkburger = math.max(0, self.items.darkburger - 1)
        self:showText("* " .. member.name .. " used a DARKBURGER.\n* " .. target.name .. " recovered " .. amount .. " HP.", function()
            self:finishAction(action)
            self.state = "ACTIONS"
            self:tryProcessNextAction()
        end)
    end
end

function Battle:addTension(amount)
    local old = self.tension
    self.tension = Util.clamp(self.tension + amount, 0, self.maxTension)
    if self.tension > old then self.tensionFlash = 0.25 end
end

function Battle:removeTension(amount)
    self.tension = Util.clamp(self.tension - amount, 0, self.maxTension)
end

function Battle:resolveAttackLane(lane)
    lane.stopped = true
    lane.accuracy = 1 - math.min(1, math.abs(lane.position - 0.5) / 0.5)
    local member = self.party[lane.action.character_id]
    lane.damage = math.max(1, math.floor(member.attack * (1.5 + lane.accuracy * 3.5) - self.enemy.defense * 2))
    self.enemy.hp = math.max(0, self.enemy.hp - lane.damage)
end

function Battle:finishAttacks()
    local total = 0
    for _, lane in ipairs(self.attackLanes) do total = total + lane.damage end
    if self.enemy.hp <= 0 then
        self.enemy.defeated = true
        self:showText("* The party dealt " .. total .. " damage!\n* " .. self.enemy.name .. " was defeated.", function()
            self:setState("VICTORY")
        end)
    else
        self:showText("* The party dealt " .. total .. " damage!", function()
            self:setState("ENEMYDIALOGUE")
        end)
    end
end

function Battle:startDefending()
    self:setState("DEFENDING")
end

function Battle:spawnBullet()
    local arena = self.arena
    local pattern = self.wavePattern
    local bullet = {w = 5, h = 5, grazed = false, damage = 10}

    if pattern == 1 then
        bullet.x = arena.x + arena.w + 8
        bullet.y = arena.y + love.math.random(3, arena.h - 8)
        bullet.vx = -(82 + love.math.random(0, 18))
        bullet.vy = 0
    elseif pattern == 2 then
        bullet.x = arena.x + love.math.random(4, arena.w - 8)
        bullet.y = arena.y - 8
        bullet.vx = love.math.random(-20, 20)
        bullet.vy = 72 + love.math.random(0, 24)
    else
        local cx = arena.x + arena.w / 2
        local cy = arena.y + arena.h / 2
        local angle = self.waveTimer * 2.4 + love.math.random() * 0.35
        bullet.x = cx + math.cos(angle) * (arena.w / 2 + 10)
        bullet.y = cy + math.sin(angle) * (arena.h / 2 + 10)
        local dx = cx - bullet.x
        local dy = cy - bullet.y
        local length = math.max(0.001, math.sqrt(dx * dx + dy * dy))
        bullet.vx = dx / length * 62
        bullet.vy = dy / length * 62
    end

    table.insert(self.bullets, bullet)
end

function Battle:hurtParty(index, amount)
    local member = self.party[index]
    if not member or member.hp <= 0 then return end
    local reduced = math.max(1, amount - member.defense)
    if member.defending then reduced = math.max(1, math.floor(reduced * 0.65)) end
    member.hp = math.max(0, member.hp - reduced)
    member.flash = 0.8
    if member.hp <= 0 then
        member.down = true
        member.animation = "down"
    end
    if self:allPartyDown() then
        self.result = "The party was defeated.\nPress Z to return."
        self:setState("RESULT")
    end
end

function Battle:allPartyDown()
    for _, member in ipairs(self.party) do
        if member.hp > 0 then return false end
    end
    return true
end


return Battle
