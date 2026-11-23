local Nursery = {}

-- Pairs are indexed in each biome's ordinary egg pool. The client receives only discovered recipes.
local pairsByBiome = {
    {
        {1, 2}, {3, 9}, {4, 7}, {2, 8}, {5, 11}, {1, 10}, {3, 6}, {7, 12},
        {2, 4}, {5, 9}, {1, 6}, {8, 10}, {4, 11}, {3, 12}, {6, 10}, {7, 11},
    },
    {
        {1, 2}, {4, 9}, {3, 8}, {2, 6}, {5, 12}, {1, 11}, {4, 7}, {8, 10},
        {2, 5}, {6, 9}, {1, 7}, {3, 11}, {7, 12}, {4, 12}, {5, 10}, {6, 11},
    },
    {
        {1, 2}, {5, 9}, {4, 8}, {2, 7}, {3, 11}, {1, 10}, {5, 6}, {8, 12},
        {2, 4}, {6, 9}, {1, 8}, {3, 12}, {7, 11}, {6, 10}, {3, 7}, {4, 11}, {5, 12},
    },
}

local function pairKey(first, second)
    if first > second then
        first, second = second, first
    end
    return first .. ":" .. second
end

function Nursery.recipes(rules)
    local byPair, byOffspring = {}, {}
    for biomeIndex, pairsForBiome in ipairs(pairsByBiome) do
        local vault = rules.Vaults[biomeIndex]
        for offspringIndex, pair in ipairs(pairsForBiome) do
            local first, second = vault.pets[pair[1]], vault.pets[pair[2]]
            local offspring = rules.Offspring[biomeIndex][offspringIndex]
            local key = pairKey(first.id, second.id)
            assert(not byPair[key] and not byOffspring[offspring.id], "Repeated nursery recipe")
            local recipe = {
                parents = { first, second },
                offspring = offspring,
                vault = vault,
                cost = biomeIndex + 1,
            }
            byPair[key] = recipe
            byOffspring[offspring.id] = recipe
        end
    end
    return byPair, byOffspring
end

function Nursery.find(recipes, first, second)
    return recipes[pairKey(first, second)]
end

return Nursery
