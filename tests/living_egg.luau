local LivingEgg = require("../src/shared/LivingEgg")
local Bases = require("../src/shared/Bases")
local Locale = require("../src/shared/Locale")
local Rules = require("../src/shared/Rules")

-- Stages follow carry time
assert(LivingEgg.stage(0) == 1 and LivingEgg.stage(7.9) == 1)
assert(LivingEgg.stage(8) == 2 and LivingEgg.stage(16) == 3 and LivingEgg.stage(100) == 4)
for index = 2, #LivingEgg.Stages do
    local previous, stage = LivingEgg.Stages[index - 1], LivingEgg.Stages[index]
    assert(stage.seconds > previous.seconds and stage.coins > previous.coins and stage.speed < previous.speed)
end
-- The last stage must be reachable inside one run
assert(LivingEgg.Stages[#LivingEgg.Stages].seconds < Rules.RunSeconds)

-- Glow grows only past the Meadow island
local fromX = LivingEgg.growsFrom(Rules.Vaults)
assert(fromX > Rules.Vaults[1].x and fromX < Rules.Vaults[2].x)
assert(LivingEgg.grow(5, 0.2, Rules.Vaults[1].x, fromX) == 5, "Meadow island does not count")
assert(math.abs(LivingEgg.grow(5, 0.2, Rules.Vaults[2].x, fromX) - 5.2) < 1e-9)

-- Rewards
assert(LivingEgg.coins(32, 1) == 32 and LivingEgg.coins(32, 2) == 40 and LivingEgg.coins(32, 4) == 64)
assert(LivingEgg.hatchMode(1) == "normal" and LivingEgg.hatchMode(4) == "prize")
assert(LivingEgg.speed(nil) == 1 and LivingEgg.speed(4) == 0.85)

-- Interception keeps most of the glow, but a legendary egg drops a stage
local legendary = LivingEgg.Stages[4].seconds
assert(LivingEgg.stage(LivingEgg.afterIntercept(legendary)) == 3)

-- Every biome has a prize pool for the legendary stage
for index in ipairs(Rules.Vaults) do
    local found = false
    for _, prize in ipairs(Rules.Prizes) do
        found = found or prize.vaultIndex == index
    end
    assert(found, "Missing prize pool for biome " .. index)
end

-- Bounty
assert(Bases.bounty({ rarity = "Обычный" }) == Bases.MinBounty)
assert(Bases.bounty({ rarity = "Легендарный" }) == 120 * Bases.BountyMinutes)

for _, stage in ipairs(LivingEgg.Stages) do
    assert(Locale.text("en", stage.name) ~= stage.name, "Missing English: " .. stage.name)
end

print("Eggstride living egg: OK")
