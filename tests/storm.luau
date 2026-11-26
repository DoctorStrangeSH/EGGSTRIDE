local Storm = require("../src/shared/Storm")
local Glide = require("../src/shared/Glide")
local Locale = require("../src/shared/Locale")
local Rules = require("../src/shared/Rules")

-- Schedule
assert(not Storm.isStormRound(0) and not Storm.isStormRound(Storm.FirstRound - 1))
assert(Storm.isStormRound(Storm.FirstRound) and Storm.isStormRound(Storm.FirstRound + Storm.EveryRounds))
assert(not Storm.isStormRound(Storm.FirstRound + 1))
assert(Storm.state(Storm.FirstRound, false) == "warning")
assert(Storm.state(Storm.FirstRound, true) == "active")
assert(Storm.state(Storm.FirstRound - 1, true) == "next")
assert(Storm.state(Storm.FirstRound - 1, false) == nil)
assert(Storm.state(Storm.FirstRound + 1, true) == nil)
local roundSeconds = Rules.PrepareSeconds + Rules.RunSeconds
assert(Storm.EveryRounds * roundSeconds >= 8 * 60, "Storms should not come too often")

-- Spots
for roll = 1, 20 do
    assert(Storm.spotForRoll(roll))
end
for _, spot in ipairs(Storm.Spots) do
    assert(Locale.text("en", spot.label) ~= spot.label, "Missing English: " .. spot.label)
    if spot.updraft then
        local found = false
        for _, updraft in ipairs(Glide.Updrafts) do
            found = found or (updraft.x == spot.x and updraft.z == spot.z and updraft.height >= Storm.EggHeight)
        end
        assert(found, "Spot needs a permanent updraft: " .. spot.id)
    else
        -- A glider topping out in the storm updraft reaches the egg prompt.
        assert(Storm.UpdraftHeight - Storm.EggHeight <= Storm.PromptDistance)
    end
end

-- Rewards are real mythic prize pets
local prizePets = {}
for _, prize in ipairs(Rules.Prizes) do
    for _, pet in ipairs(prize.pets) do
        prizePets[pet.id] = pet
    end
end
for _, id in ipairs(Storm.Pets) do
    assert(prizePets[id] and prizePets[id].rarity == "Мифический", "Not a mythic prize pet: " .. id)
end

print("Eggstride storm: OK")
