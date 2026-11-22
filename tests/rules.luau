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
local species = {}
for _, vault in ipairs(Rules.Vaults) do
    local counts = {}
    for roll = 1, 100 do
        local egg = Rules.eggForRoll(vault, roll)
        counts[egg] = (counts[egg] or 0) + 1
    end
    for _, egg in ipairs(vault.eggs) do
        assert(counts[egg] == egg.weight, "Uneven pool: " .. egg.id)
        assert(not species[egg.id], "Species appears in multiple biome pools: " .. egg.id)
        species[egg.id] = true
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
print("Eggstride rules: OK")
