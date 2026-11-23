local Rules = require("../src/shared/Rules")
local Loot = require("../src/server/Loot")
local RoundPrize = require("../src/server/RoundPrize")
local Nursery = require("../src/server/Nursery")

local function phase(at, expectedOpen, expectedLeft)
    local open, left = Rules.clock(at)
    assert(open == expectedOpen and left == expectedLeft, "Unexpected phase at " .. at)
end

phase(0, false, 7)
phase(6.5, false, 1)
phase(7, true, 55)
phase(61.5, true, 1)
phase(62, false, 7)
phase(69, true, 55)
assert(Rules.speed(1, false) == 16)
assert(Rules.speed(5, true) == 27)
assert(Rules.StartCoins == Rules.UpgradeCosts[1])
assert(Rules.canCollect(false, true, false))
assert(not Rules.canCollect(true, true, false))
assert(not Rules.canCollect(false, false, false))
assert(not Rules.canCollect(false, true, true))

local prize = RoundPrize.new()
assert(RoundPrize.claim(prize, "first"))
assert(not RoundPrize.claim(prize, "second"))
assert(not RoundPrize.deliver(prize, "second"))
assert(not RoundPrize.release(prize, "second"))
assert(RoundPrize.release(prize, "first"))
assert(RoundPrize.claim(prize, "second"))
assert(RoundPrize.deliver(prize, "second"))
assert(not RoundPrize.deliver(prize, "second"))
assert(not RoundPrize.claim(prize, "first"))
assert(RoundPrize.claim(RoundPrize.new(), "first"))

local petIds = {}
for index, vault in ipairs(Rules.Vaults) do
    -- Budget extra distance for lateral movement and the detour around the wind trail.
    local outward = (vault.x + 20) / Rules.speed(vault.tier, false)
    local home = (vault.x - Rules.HatchX + 32) / Rules.speed(vault.tier, true)
    assert(outward + home + 3 < Rules.RunSeconds, "Unlock-tier route budget: " .. vault.name)

    assert(#vault.pets == 12)
    for _, pet in ipairs(vault.pets) do
        assert(pet.id:match("^[a-z_]+$") and #pet.id <= 32, "Invalid companion id: " .. pet.id)
        assert(not petIds[pet.id], "Duplicate companion id: " .. pet.id)
        petIds[pet.id] = true
    end
    local ordinary = Loot.eggForRoll(index, 1)
    local rare = Loot.eggForRoll(index, 100)
    assert(ordinary ~= rare)
    assert(ordinary.ability == rare.ability and Rules.Abilities[ordinary.ability])
    assert(Loot.eggForRoll(index, ordinary.weight) == ordinary)
    assert(Loot.eggForRoll(index, ordinary.weight + 1) == rare)
    assert(ordinary.weight + rare.weight == 100)
    for _, egg in ipairs({ ordinary, rare }) do
        local rareCount, drops = 0, {}
        for roll = 1, 10000 do
            local result = Loot.hatchForRoll(vault, egg, roll)
            assert(table.find(vault.pets, result), "Wrong biome")
            drops[result.id] = true
            if result.rarity == "Редкий" then
                rareCount += 1
            end
        end
        for _, pet in ipairs(vault.pets) do
            assert(drops[pet.id], "Unreachable pet: " .. pet.id)
        end
        assert(rareCount == (if egg == ordinary then 1500 else 3500))
    end
end
assert(Rules.canUseVault(1, Rules.Vaults[1]) and not Rules.canUseVault(1, Rules.Vaults[2]))
assert(Rules.canUseVault(2, Rules.Vaults[2]) and not Rules.canUseVault(2, Rules.Vaults[3]))
assert(Rules.canUseVault(3, Rules.Vaults[3]))
assert(2 * Rules.Vaults[1].coins >= Rules.UpgradeCosts[2])

local amberPrize = RoundPrize.new()
local stormPrize = RoundPrize.new()
assert(RoundPrize.claim(amberPrize, "first"))
assert(RoundPrize.claim(stormPrize, "second"))
assert(RoundPrize.deliver(stormPrize, "second"))
assert(RoundPrize.release(amberPrize, "first"))
assert(RoundPrize.claim(amberPrize, "third"))

assert(#Rules.Prizes == #Rules.Vaults)
for index, prize in ipairs(Rules.Prizes) do
    assert(prize.vaultIndex == index and prize.id == Rules.Vaults[index].id and #prize.pets == 5)
    local drops, highRarityCount = {}, 0
    for roll = 1, 1000 do
        local pet = Loot.prizePetForRoll(prize.pets, roll)
        assert(table.find(prize.pets, pet) and pet.rarity ~= "Обычный")
        drops[pet.id] = (drops[pet.id] or 0) + 1
        if pet.rarity ~= "Редкий" then
            highRarityCount += 1
        end
    end
    for _, pet in ipairs(prize.pets) do
        assert(not petIds[pet.id] and drops[pet.id] > 0)
        petIds[pet.id] = true
    end
    assert(highRarityCount >= 700 and drops[prize.pets[5].id] == 20)
end

local byPair, byOffspring = Nursery.recipes(Rules)
for index, offspring in ipairs(Rules.Offspring) do
    for _, pet in ipairs(offspring) do
        assert(not petIds[pet.id] and byOffspring[pet.id])
        petIds[pet.id] = true
        local recipe = byOffspring[pet.id]
        assert(recipe.vault == Rules.Vaults[index])
        local first, second = table.unpack(recipe.parents)
        assert(first ~= second and table.find(recipe.vault.pets, first) and table.find(recipe.vault.pets, second))
        assert(Nursery.find(byPair, first.id, second.id) == recipe and Nursery.find(byPair, second.id, first.id) == recipe)
    end
end
local total = 0
for _ in pairs(petIds) do
    total += 1
end
assert(total == 100)
for index, mutation in ipairs(Rules.Mutations) do
    assert(mutation.vault == Rules.Vaults[index] and byOffspring[mutation.parent.id])
    assert(not petIds[mutation.pet.id] and mutation.cost == 2 and mutation.pet.mutated)
    petIds[mutation.pet.id] = true
end
assert(Rules.returnBridgeStage(0, -0.4) == 0)
assert(Rules.returnBridgeStage(0, 0.25) == 1)
assert(Rules.returnBridgeStage(1, 0) == 1)
assert(Rules.returnBridgeStage(1, -0.25) == 2)
assert(Rules.returnBridgeStage(2, 0.5) == 2)


assert(Rules.onboardingObjective(nil, false, false, 1) == nil)
assert(Rules.onboardingObjective(1, false, false, 1) == "train")
assert(Rules.onboardingObjective(1, false, false, 2) == "gate")
assert(Rules.onboardingObjective(1, true, false, 1) == "firstEgg")
assert(Rules.onboardingObjective(2, true, false, 2) == "firstEgg")
assert(Rules.onboardingObjective(3, true, true, 2) == "collection")
assert(Rules.onboardingObjective(3, false, false, 2) == "gate")
assert(Rules.onboardingObjective(3, true, false, 2) == "nextEgg")
assert(Rules.onboardingObjective(4, true, false, 2) == nil)
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
local thunder = { Loot.eggForRoll(3, 1), Loot.eggForRoll(3, 100) }
assert(thunder[1].ability == "relay" and thunder[2].ability == "relay")
local required = Rules.StormTrial.secondsLeft
assert(Rules.stormTrialComplete(thunder[1], true, required))
assert(Rules.stormTrialComplete(thunder[2], true, required))
assert(not Rules.stormTrialComplete(thunder[1], true, required - 1))
assert(not Rules.stormTrialComplete(thunder[1], false, required + 1))
assert(not Rules.stormTrialComplete(Loot.eggForRoll(1, 1), true, required + 1))
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
assert(Rules.improvedDelivery(nil, 0) == nil and Rules.improvedDelivery(nil, Rules.RunSeconds + 1) == nil)
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
local runner = { coins = 10 }
local target = Rules.Weekly.rewardTime
assert(Rules.claimWeeklyReward(runner, 17, target + 1, true) == nil)
assert(Rules.claimWeeklyReward(runner, 17, target, false) == nil)
assert(runner.coins == 10 and runner.weeklyRewardWeek == nil)
assert(Rules.claimWeeklyReward(runner, 17, target, true) == Rules.Weekly.rewardCoins)
assert(Rules.claimWeeklyReward(runner, 17, target - 100, true) == nil)
assert(Rules.claimWeeklyReward(runner, 16, target, true) == nil)
assert(Rules.claimWeeklyReward(runner, 18, target, true) == Rules.Weekly.rewardCoins)
assert(runner.coins == 10 + Rules.Weekly.rewardCoins * 2 and runner.weeklyRewardWeek == 18)
print("Eggstride rules: OK")
