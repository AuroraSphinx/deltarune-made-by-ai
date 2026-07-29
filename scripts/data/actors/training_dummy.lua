-- Derived from Kristal's BSD-3-Clause mod template actor.
local actor, super = Class(Actor, "training_dummy")

function actor:init()
    super.init(self)

    self.name = "Training Dummy"
    self.width = 27
    self.height = 45
    self.hitbox = {0, 25, 19, 14}
    self.color = {1, 0, 0}
    self.path = "enemies/training_dummy"
    self.default = "idle"
    self.flip = nil
    self.voice = nil
    self.portrait_path = nil
    self.can_blush = false
    self.talk_sprites = {}
    self.animations = {
        ["idle"] = {"idle", 0.25, true}
    }
    self.offsets = {
        ["idle"] = {0, 0}
    }
end

return actor
