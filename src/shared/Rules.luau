local Rules = {}

Rules.PrepareSeconds = 9
Rules.RunSeconds = 25
Rules.CarryMultiplier = 0.75
Rules.StartCoins = 15
Rules.GateX = 28
Rules.Vaults = {
    { name = "Луговой", x = 63, tier = 1, coins = 32, pet = "Листохвост" },
    { name = "Янтарный", x = 143, tier = 2, coins = 54, pet = "Янтарный краб" },
    { name = "Грозовой", x = 252, tier = 4, coins = 95, pet = "Громопух" },
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

return Rules
