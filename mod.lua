local battle_started = false

function Mod:init()
    print("Loaded " .. self.info.name .. " on Kristal.")
end

function Mod:postInit(new_file)
    if battle_started then
        return
    end

    battle_started = true

    -- Enter the real Kristal battle engine after the world finishes loading.
    Game.world.timer:after(0.15, function()
        if Game.state == "OVERWORLD" and not Game.battle then
            Game:encounter("training", true)
        end
    end)
end
