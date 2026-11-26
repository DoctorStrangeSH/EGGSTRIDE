local Rebirth = require("../src/shared/Rebirth")
local Storm = require("../src/shared/Storm")
local Bases = require("../src/shared/Bases")
local Profile = require("../src/server/Profile")
local Rules = require("../src/shared/Rules")

Rules.Bases = Bases

-- Costs grow and stop at the maximum
assert(Rebirth.cost(0) == Rebirth.BaseCost and Rebirth.cost(1) == Rebirth.BaseCost * Rebirth.CostGrowth)
assert(Rebirth.cost(Rebirth.Max) == nil)
assert(Rebirth.incomeMultiplier(0) == 1 and Rebirth.incomeMultiplier(2) == 2)
assert(Rebirth.runCoinMultiplier(nil) == 1 and Rebirth.runCoinMultiplier(4) == 2)

local function entry(fields)
    local result = { coins = 10000, tier = 5, base = { "a", "b" }, baseSlots = 6, rebirths = 0 }
    for key, value in pairs(fields or {}) do
        result[key] = value
    end
    return result
end

-- A rebirth resets coins, speed and the base
local e = entry()
assert(Rebirth.apply(e, 15, Bases.MaxSlots))
assert(e.rebirths == 1 and e.coins == 15 and e.tier == 1 and #e.base == 0 and e.baseSlots == 6)
-- Second rebirth grants a free slot
e.coins = Rebirth.cost(1)
assert(Rebirth.apply(e, 15, Bases.MaxSlots) and e.baseSlots == 7)
-- Refusals
assert(select(2, Rebirth.apply(entry({ coins = 10 }), 15, Bases.MaxSlots)) == "coins")
assert(select(2, Rebirth.apply(entry({ egg = {} }), 15, Bases.MaxSlots)) == "busy")
assert(select(2, Rebirth.apply(entry({ golden = true }), 15, Bases.MaxSlots)) == "busy")
assert(select(2, Rebirth.apply(entry({ rebirths = Rebirth.Max }), 15, Bases.MaxSlots)) == "max")
local full = entry({ rebirths = 1, coins = Rebirth.cost(1), baseSlots = Bases.MaxSlots })
assert(Rebirth.apply(full, 15, Bases.MaxSlots) and full.baseSlots == Bases.MaxSlots)

-- Rebirths are saved
local stored = Profile.new(20)
stored.rebirths = 3
assert(Profile.read(stored, {}, Rules).rebirths == 3)
stored.rebirths = -1
assert(Profile.read(stored, {}, Rules).rebirths == 0)

-- Bought storms
local forced = {}
local round = Storm.nextFreeRound(0, forced)
assert(round == 1)
forced[round] = "Buyer"
assert(Storm.state(1, true, forced) == "active" and Storm.state(0, true, forced) == "next")
assert(Storm.nextFreeRound(0, forced) == 2, "A second purchase queues behind the first")
assert(Storm.nextFreeRound(Storm.FirstRound - 1, {}) == Storm.FirstRound + 1, "Scheduled storms are skipped")

print("Eggstride rebirth: OK")
