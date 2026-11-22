local Rules = {}

Rules.PrepareSeconds = 9
Rules.RunSeconds = 25
Rules.CarryMultiplier = 0.75
Rules.StartCoins = 15
Rules.GateX = 28
Rules.VineDuration = 6
Rules.RarePetChance = { ["Обычное"] = 15, ["Редкое"] = 35 }
Rules.Vaults = {
    {
        name = "Луговой", x = 63, tier = 1, coins = 32,
        pets = {
            common = { id = "leaf_tail", name = "Листохвост", rarity = "Обычный", color = { 176, 220, 111 } },
            rare = { id = "dew_moth", name = "Росокрыл", rarity = "Редкий", color = { 113, 232, 235 } },
        },
        eggs = {
            { id = "leaf_shell", name = "Листовое яйцо", rarity = "Обычное", weight = 80, ability = "Лиана", color = { 176, 220, 111 } },
            { id = "dew_shell", name = "Яйцо росы", rarity = "Редкое", weight = 20, ability = "Лиана", color = { 113, 232, 235 } },
        },
    },
    {
        name = "Янтарный", x = 143, tier = 2, coins = 54,
        pets = {
            common = { id = "amber_crab", name = "Янтарный краб", rarity = "Обычный", color = { 255, 178, 76 } },
            rare = { id = "prism_fox", name = "Призмолис", rarity = "Редкий", color = { 255, 113, 165 } },
        },
        eggs = {
            { id = "amber_shell", name = "Янтарное яйцо", rarity = "Обычное", weight = 85, color = { 255, 178, 76 } },
            { id = "prism_shell", name = "Призматическое яйцо", rarity = "Редкое", weight = 15, color = { 255, 113, 165 } },
        },
    },
    {
        name = "Грозовой", x = 252, tier = 4, coins = 95,
        pets = {
            common = { id = "thunder_puff", name = "Громопух", rarity = "Обычный", color = { 182, 150, 255 } },
            rare = { id = "lightning_kite", name = "Молниехвост", rarity = "Редкий", color = { 255, 237, 108 } },
        },
        eggs = {
            { id = "thunder_shell", name = "Грозовое яйцо", rarity = "Обычное", weight = 90, color = { 182, 150, 255 } },
            { id = "lightning_shell", name = "Яйцо молнии", rarity = "Редкое", weight = 10, color = { 255, 237, 108 } },
        },
    },
}
Rules.Speeds = { 16, 20, 24, 30, 36 }
Rules.UpgradeCosts = { 15, 35, 65, 95 }

function Rules.clock(elapsed)
    local offset = elapsed % (Rules.PrepareSeconds + Rules.RunSeconds)
    if offset < Rules.PrepareSeconds then
        return false, math.ceil(Rules.PrepareSeconds - offset)
    end
    return true, math.ceil(Rules.PrepareSeconds + Rules.RunSeconds - offset)
end

function Rules.speed(tier, carrying)
    return Rules.Speeds[tier] * (if carrying then Rules.CarryMultiplier else 1)
end

function Rules.canCollect(tier, vault, carrying, open, delivered)
    return open and not carrying and not delivered and tier >= vault.tier
end

function Rules.eggForRoll(vault, roll)
    for _, egg in ipairs(vault.eggs) do
        roll -= egg.weight
        if roll <= 0 then
            return egg
        end
    end
    error("Egg roll exceeds the biome pool")
end

function Rules.hatchForRoll(vault, egg, roll)
    return if roll <= Rules.RarePetChance[egg.rarity] then vault.pets.rare else vault.pets.common
end

return Rules
