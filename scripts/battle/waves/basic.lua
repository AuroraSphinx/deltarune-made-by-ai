-- Derived from Kristal's BSD-3-Clause mod template wave.
local Basic, super = Class(Wave)

function Basic:onStart()
    self.timer:every(1 / 3, function()
        local x = SCREEN_WIDTH + 20
        local y = MathUtils.random(Game.battle.arena.top, Game.battle.arena.bottom)
        local bullet = self:spawnBullet("smallbullet", x, y, math.rad(180), 8)
        bullet.remove_offscreen = false
    end)
end

function Basic:update()
    super.update(self)
end

return Basic
