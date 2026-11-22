local Rules = require("../src/shared/Rules")

local function phase(at, expectedOpen, expectedLeft)
    local open, left = Rules.clock(at)
    assert(open == expectedOpen and left == expectedLeft, "Unexpected phase at " .. at)
end

phase(0, false, 9)
phase(8.5, false, 1)
phase(9, true, 25)
phase(33.5, true, 1)
phase(34, false, 9)
phase(43, true, 25)
assert(Rules.speed(1, false) == 16)
assert(Rules.speed(5, true) == 27)
assert(Rules.StartCoins == Rules.UpgradeCosts[1])
assert(Rules.canCollect(1, Rules.Vaults[1], false, true, false))
assert(not Rules.canCollect(1, Rules.Vaults[2], false, true, false))
assert(not Rules.canCollect(5, Rules.Vaults[3], true, true, false))
assert(not Rules.canCollect(5, Rules.Vaults[3], false, false, false))
assert(not Rules.canCollect(5, Rules.Vaults[3], false, true, true))
assert(not Rules.canCollect(3, Rules.Vaults[3], false, true, false))
assert(Rules.canCollect(4, Rules.Vaults[3], false, true, false))
for _, vault in ipairs(Rules.Vaults) do
    local outward = (vault.x - Rules.GateX) / Rules.speed(vault.tier, false)
    local home = (vault.x - 14) / Rules.speed(vault.tier, true)
    assert(outward + home < Rules.RunSeconds, "Impossible minimum-tier route: " .. vault.name)
end
local shellIds = {}
local petIds = {}
for _, vault in ipairs(Rules.Vaults) do
    for _, pet in pairs(vault.pets) do
        assert(pet.id:match("^[a-z_]+$") and #pet.id <= 32, "Invalid companion id: " .. pet.id)
        assert(not petIds[pet.id], "Duplicate companion id: " .. pet.id)
        petIds[pet.id] = true
    end
    local counts = {}
    for roll = 1, 100 do
        local egg = Rules.eggForRoll(vault, roll)
        counts[egg] = (counts[egg] or 0) + 1
    end
    for _, egg in ipairs(vault.eggs) do
        assert(counts[egg] == egg.weight, "Uneven pool: " .. egg.id)
        assert(not shellIds[egg.id], "Species appears in multiple biome pools: " .. egg.id)
        shellIds[egg.id] = true
        assert(not egg.ability or Rules.Abilities[egg.ability], "Unknown egg ability: " .. egg.id)
        local rare = 0
        for roll = 1, 100 do
            local result = Rules.hatchForRoll(vault, egg, roll)
            assert(result == vault.pets.rare or result == vault.pets.common, "Wrong biome")
            if result == vault.pets.rare then
                rare += 1
            end
        end
        assert(rare == Rules.RarePetChance[egg.rarity], "Wrong hatch odds: " .. egg.id)
    end
end
assert(Rules.onboardingAfterPickup(1) == 2)
assert(Rules.onboardingAfterPickup(2) == 2)
assert(Rules.onboardingAfterPickup(3) == 4)
assert(Rules.onboardingAfterPickup(4) == 4)
assert(Rules.windDirection(0) == 1 and Rules.windDirection(1) == -1 and Rules.windDirection(2) == 1)
assert(Rules.windFactor(1, 20) == 1.30 and Rules.windFactor(1, -20) == 0.70)
assert(Rules.windFactor(-1, -20) == 1.30 and Rules.windFactor(-1, 20) == 0.70)
assert(Rules.windFactor(0, 20) == 1 and Rules.windFactor(1, 0.2) == 1)
assert(math.abs(Rules.speed(2, true) * Rules.windFactor(1, -20) - 10.5) < 1e-9)
assert(Rules.windFactor(1, -20, true) == 1)
assert(Rules.windFactor(1, 20, true) == Rules.WindTailwind)
assert(Rules.windFactor(-1, 20, false) == Rules.WindHeadwind)
assert(Rules.windFactor(0, -20, true) == 1)
assert(Rules.speed(2, true) * Rules.windFactor(1, -20, true) == 15)
for _, egg in ipairs(Rules.Vaults[3].eggs) do
    assert(egg.ability == "relay")
end
assert(Rules.abilityEffect(Rules.Abilities.relay) == "Переносит на Янтарный остров")
assert(string.find(Rules.abilityEffect(Rules.Abilities.vine), tostring(Rules.Abilities.vine.duration), 1, true))
local thunder = Rules.Vaults[3].eggs
local required = Rules.StormTrial.secondsLeft
assert(Rules.stormTrialComplete(thunder[1], true, required))
assert(Rules.stormTrialComplete(thunder[2], true, required))
assert(not Rules.stormTrialComplete(thunder[1], true, required - 1))
assert(not Rules.stormTrialComplete(thunder[1], false, required + 1))
assert(not Rules.stormTrialComplete(Rules.Vaults[1].eggs[1], true, required + 1))
assert(not Rules.stormTrialComplete(nil, true, required + 1))
assert(Rules.canSwitchWind(1, false, true))
assert(not Rules.canSwitchWind(1, false, false))
assert(not Rules.canSwitchWind(1, true, true))
assert(not Rules.canSwitchWind(-1, false, true))
assert(not Rules.canSwitchWind(0, false, true))
assert(Rules.improvedDelivery(nil, 10.235) == 10235)
assert(Rules.improvedDelivery(10235, 10.234) == 10234)
assert(Rules.improvedDelivery(10235, 10.235) == nil)
assert(Rules.improvedDelivery(10235, 11) == nil)
assert(Rules.improvedDelivery(nil, 0) == nil and Rules.improvedDelivery(nil, 26) == nil)
assert(Rules.deliveryTimeText(10240) == "10,24 сек.")
local monday = 4 * 86400
assert(Rules.weekId(monday - 1) == -1 and Rules.weekId(monday) == 0)
assert(Rules.weekId(monday + 7 * 86400 - 1) == 0 and Rules.weekId(monday + 7 * 86400) == 1)
assert(Rules.weeklyBest({ week = 1, time = 12150 }, 1) == 12150)
assert(Rules.weeklyBest({ week = 1, time = 12150 }, 2) == nil)
assert(Rules.improvedDelivery(nil, 29, Rules.Weekly.duration) == 29000)
assert(Rules.improvedDelivery(nil, Rules.Weekly.duration + 0.01, Rules.Weekly.duration) == nil)
assert(#Rules.Weekly.order == #Rules.Weekly.labels and Rules.Weekly.order[Rules.Weekly.eggStep] == "Egg")
assert(Rules.weeklySplitPlausible(40, 2.0, false))
assert(Rules.weeklySplitPlausible(40, 2.0, true))
assert(not Rules.weeklySplitPlausible(40, 0.3, true))
assert(Rules.weeklySplitPlausible(40, 1, false) and not Rules.weeklySplitPlausible(40, 1, true))
print("Eggstride rules: OK")
