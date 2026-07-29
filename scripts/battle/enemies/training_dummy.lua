-- Derived from Kristal's BSD-3-Clause mod template enemy.
local TrainingDummy, super = Class(EnemyBattler)

function TrainingDummy:init()
    super.init(self)

    self.name = "Training Dummy"
    self:setActor("training_dummy")

    self.max_health = 450
    self.health = 450
    self.attack = 4
    self.defense = 0
    self.money = 100
    self.spare_points = 20

    self.waves = {"basic"}
    self.dialogue = {"..."}
    self.check = "AT 4 DF 0\n* A proper Kristal enemy.\n* It uses the real party battle engine."
    self.text = {
        "* The dummy waits for the party's\ncommands.",
        "* TP sparks through the air.",
        "* This is finally not Undertale."
    }

    self:registerAct("Smile")
    self:registerAct("Group Compliment", "", {"susie", "ralsei"})
end

function TrainingDummy:onAct(battler, name)
    if name == "Smile" then
        self:addMercy(50)
        self.dialogue_override = "... ^^"
        return "* Kris smiled.\n* The dummy's MERCY increased."
    elseif name == "Group Compliment" then
        self:addMercy(100)
        return "* The whole party complimented the\ndummy.\n* It became spareable!"
    elseif name == "Standard" then
        self:addMercy(25)
        return "* " .. battler.chara:getName() .. " performed their\nX-Action."
    end

    return super.onAct(self, battler, name)
end

return TrainingDummy
