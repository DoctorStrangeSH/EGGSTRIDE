-- Rebirth: give up coins, speed and the pets on your base for a permanent bonus.
-- The collection (journal, nursery, season) is kept.
local Rebirth = {}

Rebirth.Max = 10
Rebirth.BaseCost = 3000
-- Each rebirth costs this much more than the previous one.
Rebirth.CostGrowth = 2
-- Permanent bonuses per rebirth.
Rebirth.IncomeBonus = 0.5
Rebirth.RunCoinBonus = 0.25
-- A free base slot every second rebirth, up to the plot limit.
Rebirth.SlotEvery = 2

function Rebirth.cost(rebirths)
    if rebirths >= Rebirth.Max then
        return nil
    end
    return Rebirth.BaseCost * Rebirth.CostGrowth ^ rebirths
end

function Rebirth.incomeMultiplier(rebirths)
    return 1 + (rebirths or 0) * Rebirth.IncomeBonus
end

function Rebirth.runCoinMultiplier(rebirths)
    return 1 + (rebirths or 0) * Rebirth.RunCoinBonus
end

-- Applies a rebirth to a plain entry table. Returns ok, reason.
-- entry: coins, tier, base, baseSlots, rebirths; startCoins: coins after the reset.
function Rebirth.apply(entry, startCoins, maxSlots)
    local cost = Rebirth.cost(entry.rebirths)
    if not cost then
        return false, "max"
    end
    if entry.coins < cost then
        return false, "coins"
    end
    if entry.egg or entry.stolen or entry.golden or entry.weekly then
        return false, "busy"
    end
    entry.rebirths += 1
    entry.coins = startCoins
    entry.tier = 1
    table.clear(entry.base)
    if entry.rebirths % Rebirth.SlotEvery == 0 and entry.baseSlots < maxSlots then
        entry.baseSlots += 1
    end
    return true
end

return Rebirth
