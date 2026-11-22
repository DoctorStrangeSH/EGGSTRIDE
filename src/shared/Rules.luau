local Rules = {}

Rules.PrepareSeconds = 9
Rules.RunSeconds = 25
Rules.CarryMultiplier = 0.75
Rules.StartCoins = 15
Rules.GateX = 28
Rules.Vaults = {
    {
        name = "Луговой", x = 63, tier = 1, coins = 32,
        eggs = {
            { id = "leaf_tail", name = "Листовое яйцо", pet = "Листохвост", rarity = "Обычное", weight = 80, color = { 176, 220, 111 } },
            { id = "dew_moth", name = "Яйцо росы", pet = "Росокрыл", rarity = "Редкое", weight = 20, color = { 113, 232, 235 } },
        },
    },
    {
        name = "Янтарный", x = 143, tier = 2, coins = 54,
        eggs = {
            { id = "amber_crab", name = "Янтарное яйцо", pet = "Янтарный краб", rarity = "Обычное", weight = 85, color = { 255, 178, 76 } },
            { id = "prism_fox", name = "Призматическое яйцо", pet = "Призмолис", rarity = "Редкое", weight = 15, color = { 255, 113, 165 } },
        },
    },
    {
        name = "Грозовой", x = 252, tier = 4, coins = 95,
        eggs = {
            { id = "thunder_puff", name = "Грозовое яйцо", pet = "Громопух", rarity = "Обычное", weight = 90, color = { 182, 150, 255 } },
            { id = "lightning_kite", name = "Яйцо молнии", pet = "Молниехвост", rarity = "Редкое", weight = 10, color = { 255, 237, 108 } },
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

return Rules
