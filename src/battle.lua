-- The standalone project API stays unchanged. The implementation lives in the
-- vendored Kristal legacy port so upstream-derived code is clearly separated.
local Battle = require("vendor.kristal_legacy.battle")
local ctx = Battle._ctx
local UI_TOP = ctx.UI_TOP

local originalDrawBackground = Battle.drawBackground
local originalDrawPartyMember = Battle.drawPartyMember

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

function Battle:drawPartyMember(member, x, y)
    if member.id ~= "ralsei" or not self.assets or not self.assets:has("ralsei") then
        return originalDrawPartyMember(self, member, x, y)
    end

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

    self.assets:draw("ralsei", x, y + bob, {centered = true})

    if member.defending then
        love.graphics.setColor(
            member.color[1],
            member.color[2],
            member.color[3],
            0.55 + math.sin(member.animationTimer * 8) * 0.25
        )
        love.graphics.circle("line", x, y - 5, 13)
    end
end

return Battle
