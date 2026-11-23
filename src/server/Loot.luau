local Loot = {}

-- Indexes match the public collection. Weights are server-side and sum to 1000.
local prizeWeights = { 300, 260, 240, 180, 20 }

function Loot.prizePetForRoll(pets, roll)
    for index, weight in ipairs(prizeWeights) do
        roll -= weight
        if roll <= 0 then
            return pets[index]
        end
    end
    error("Prize roll exceeds the prize pool")
end

local rareChance = { ordinary = 15, rare = 35 }
local eggs = {
    {
        { rarity = "ordinary", weight = 80, ability = "vine" },
        { rarity = "rare", weight = 20, ability = "vine" },
    },
    {
        { rarity = "ordinary", weight = 85, ability = "anchor" },
        { rarity = "rare", weight = 15, ability = "anchor" },
    },
    {
        { rarity = "ordinary", weight = 90, ability = "relay" },
        { rarity = "rare", weight = 10, ability = "relay" },
    },
}

function Loot.eggForRoll(vaultIndex, roll)
    for _, egg in ipairs(eggs[vaultIndex]) do
        roll -= egg.weight
        if roll <= 0 then
            return egg
        end
    end
    error("Egg roll exceeds the biome pool")
end

function Loot.hatchForRoll(vault, egg, roll)
    local rareLimit = rareChance[egg.rarity] * 100
    local rare = roll <= rareLimit
    local offset = if rare then roll else roll - rareLimit
    local size = if rare then rareLimit else 10000 - rareLimit
    local starterWeight = math.floor(size * 0.36)
    if offset <= starterWeight then
        return vault.pets[if rare then 2 else 1]
    end
    local first = if rare then 9 else 3
    local extra = if rare then 4 else 6
    local extraIndex = math.floor((offset - starterWeight - 1) * extra / (size - starterWeight))
    return vault.pets[first + extraIndex]
end

return Loot
