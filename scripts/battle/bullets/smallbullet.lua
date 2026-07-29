-- Derived from Kristal's BSD-3-Clause mod template bullet.
local SmallBullet, super = Class(Bullet)

function SmallBullet:init(x, y, dir, speed)
    super.init(self, x, y, "bullets/smallbullet")
    self.physics.direction = dir
    self.physics.speed = speed
end

function SmallBullet:update()
    super.update(self)
end

return SmallBullet
