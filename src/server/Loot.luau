local Loot = {}

-- Indexes match the public collection. Weights are server-side and sum to 1000.
local relicWeights = { 66, 66, 66, 66, 66, 170, 170, 170, 140, 20 }

function Loot.relicPetForRoll(pets, roll)
    for index, weight in ipairs(relicWeights) do
        roll -= weight
        if roll <= 0 then
            return pets[index]
        end
    end
    error("Relic roll exceeds the prize pool")
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
    return if roll <= rareChance[egg.rarity] then vault.pets.rare else vault.pets.common
end

return Loot
