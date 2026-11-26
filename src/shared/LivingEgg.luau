-- Living egg: an ordinary egg grows brighter and rarer the longer it is carried
-- on the far islands. Brighter eggs are slower, visible from afar and can be intercepted.
local LivingEgg = {}

LivingEgg.Stages = {
    { seconds = 0, name = "Обычное яйцо", coins = 1, speed = 1 },
    { seconds = 8, name = "Яркое яйцо", coins = 1.25, speed = 0.95, light = 8 },
    { seconds = 16, name = "Сияющее яйцо", coins = 1.5, speed = 0.9, light = 14 },
    { seconds = 30, name = "Легендарное яйцо", coins = 2, speed = 0.85, light = 22, beacon = true },
}
-- Interception: hold the prompt next to a carrier of a glowing egg.
LivingEgg.InterceptStage = 2
LivingEgg.InterceptHoldSeconds = 1
LivingEgg.InterceptRadius = 8
-- The new carrier keeps part of the glow so stealing is worth it but not a free legendary.
LivingEgg.InterceptKeep = 0.75

function LivingEgg.stage(seconds)
    local current = 1
    for index, stage in ipairs(LivingEgg.Stages) do
        if seconds >= stage.seconds then
            current = index
        end
    end
    return current
end

-- The glow only grows on the far islands and the bridges between them: east of
-- the Meadow island. A Meadow egg can still glow if its carrier takes a detour.
function LivingEgg.growsFrom(vaults)
    return vaults[1].x + 20
end

function LivingEgg.grow(seconds, dt, x, fromX)
    if x <= fromX then
        return seconds
    end
    return seconds + dt
end

function LivingEgg.coins(baseCoins, stage)
    return math.floor(baseCoins * LivingEgg.Stages[stage].coins + 0.5)
end

function LivingEgg.speed(stage)
    return LivingEgg.Stages[stage or 1].speed
end

-- How the hatch is decided at each stage.
-- 1: normal roll, 2: rare-egg roll, 3: guaranteed rare pet, 4: pet from the biome prize pool.
function LivingEgg.hatchMode(stage)
    return ({ "normal", "rareEgg", "rarePet", "prize" })[stage]
end

function LivingEgg.afterIntercept(seconds)
    return seconds * LivingEgg.InterceptKeep
end

return LivingEgg
