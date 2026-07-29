-- Derived from Kristal's BSD-3-Clause mod template encounter.
local Training, super = Class(Encounter)

function Training:init()
    super.init(self)

    self.text = "* The real battle system begins."
    self.music = "battle"
    self.background = true

    self:addEnemy("training_dummy")
end

return Training
