-- Player bases: pets on display earn coins, other players can steal them.
-- Pure rules only: no Instances, so the logic is covered by tests/bases.luau.
local Bases = {}

Bases.PlotCount = 8
Bases.StartSlots = 4
Bases.MaxSlots = 10
-- Price of each slot after the starting four.
Bases.SlotCosts = { 150, 400, 900, 1800, 3500, 6000 }

-- Coins per minute for a pet standing on the base.
Bases.IncomePerMinute = {
    ["Обычный"] = 6,
    ["Редкий"] = 15,
    ["Эпический"] = 40,
    ["Легендарный"] = 120,
    ["Мифический"] = 300,
}
-- Selling a pet from the base pays this many minutes of its income.
Bases.SellMinutes = 3

Bases.LockSeconds = 60
-- A player who just joined cannot be robbed right away.
Bases.JoinProtectionSeconds = 120
Bases.StealHoldSeconds = 1.5
-- The owner takes the pet back by catching the thief within this radius.
Bases.CatchRadius = 7
-- The thief delivers the pet by entering their own plot within this radius.
Bases.DeliverRadius = 12

Bases.Products = {
    shield = { id = "shield", name = "Щит базы", description = "Базу нельзя ограбить 10 минут", seconds = 600 },
    income = { id = "income", name = "Доход ×2", description = "Двойной доход базы 15 минут", seconds = 900 },
    storm = { id = "storm", name = "Вызвать шторм", description = "Небесный шторм для всего сервера в следующем раунде" },
}
Bases.ProductOrder = { "shield", "income", "storm" }

function Bases.income(pet)
    return Bases.IncomePerMinute[pet.rarity] or Bases.IncomePerMinute["Обычный"]
end

-- Total coins per minute of a base, given a pet catalog and boost flag.
function Bases.totalIncome(base, catalog, boosted)
    local total = 0
    for _, id in ipairs(base) do
        local pet = catalog[id]
        if pet then
            total += Bases.income(pet)
        end
    end
    return if boosted then total * 2 else total
end

-- Reward for anyone but the owner who catches a thief carrying this pet.
Bases.BountyMinutes = 2
Bases.MinBounty = 20
Bases.BountyCooldownSeconds = 60
-- Nobody can catch the thief in the first moment after the steal.
Bases.CatchGraceSeconds = 1
function Bases.bounty(pet)
    return math.max(Bases.MinBounty, Bases.income(pet) * Bases.BountyMinutes)
end

function Bases.sellPrice(pet)
    return Bases.income(pet) * Bases.SellMinutes
end

function Bases.nextSlotCost(slots)
    if slots >= Bases.MaxSlots then
        return nil
    end
    return Bases.SlotCosts[slots - Bases.StartSlots + 1]
end

-- Adds a pet to the first free slot. Returns the slot index or nil when full.
function Bases.place(base, slots, petId)
    if #base >= slots then
        return nil
    end
    table.insert(base, petId)
    return #base
end

-- Removes the pet at a slot only if it is still the expected pet.
function Bases.take(base, slot, petId)
    if base[slot] ~= petId then
        return false
    end
    table.remove(base, slot)
    return true
end

function Bases.isLocked(lockedUntil, shieldUntil, now)
    return (lockedUntil or 0) > now or (shieldUntil or 0) > now
end

-- Whether thief may start stealing the given slot of the victim.
-- Returns ok, reason.
function Bases.canSteal(thief, victim, slot, now)
    if thief == victim then
        return false, "own"
    end
    if not victim.base[slot] then
        return false, "empty"
    end
    if Bases.isLocked(victim.lockedUntil, victim.shieldUntil, now) then
        return false, "locked"
    end
    if thief.carryingEgg or thief.stolen then
        return false, "busy"
    end
    if #thief.base >= thief.slots then
        return false, "full"
    end
    for _, carried in pairs(victim.beingStolen or {}) do
        if carried == slot then
            return false, "taken"
        end
    end
    return true
end

-- Coins earned over dt seconds, carried as a fraction between ticks.
function Bases.accrue(pending, perMinute, dt)
    return pending + perMinute * dt / 60
end

return Bases
