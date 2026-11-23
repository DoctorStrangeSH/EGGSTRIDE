local Loot = {}

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
