local Bases = require("../src/shared/Bases")
local Rules = require("../src/shared/Rules")
local Profile = require("../src/server/Profile")
local Locale = require("../src/shared/Locale")

Rules.Bases = Bases

local common = { id = "a", rarity = "Обычный" }
local rare = { id = "b", rarity = "Редкий" }
local legend = { id = "c", rarity = "Легендарный" }
local catalog = { a = common, b = rare, c = legend }

-- Income and selling
assert(Bases.income(common) == 6 and Bases.income(legend) == 120)
assert(Bases.income({ rarity = "Неизвестный" }) == 6, "Unknown rarity falls back to common income")
assert(Bases.totalIncome({ "a", "b", "missing" }, catalog, false) == 21)
assert(Bases.totalIncome({ "a", "b" }, catalog, true) == 42)
assert(Bases.sellPrice(rare) == 15 * Bases.SellMinutes)
assert(math.abs(Bases.accrue(0, 60, 0.5) - 0.5) < 1e-9)

-- Slots
assert(Bases.nextSlotCost(Bases.StartSlots) == Bases.SlotCosts[1])
assert(Bases.nextSlotCost(Bases.MaxSlots - 1) == Bases.SlotCosts[#Bases.SlotCosts])
assert(Bases.nextSlotCost(Bases.MaxSlots) == nil)
assert(#Bases.SlotCosts == Bases.MaxSlots - Bases.StartSlots)

local base = {}
assert(Bases.place(base, 2, "a") == 1 and Bases.place(base, 2, "b") == 2)
assert(Bases.place(base, 2, "c") == nil, "Full base rejects pets")
assert(not Bases.take(base, 1, "b"), "Take checks the expected pet")
assert(Bases.take(base, 1, "a") and base[1] == "b" and #base == 1)

-- Locks
assert(Bases.isLocked(10, 0, 5) and Bases.isLocked(0, 10, 5))
assert(not Bases.isLocked(5, 5, 5) and not Bases.isLocked(nil, nil, 1))

-- Stealing
local function state(fields)
    local result = { base = { "a", "b" }, slots = 4, lockedUntil = 0, shieldUntil = 0, beingStolen = {} }
    for key, value in pairs(fields or {}) do
        result[key] = value
    end
    return result
end
local victim = state()
assert(Bases.canSteal(state(), victim, 1, 100))
assert(select(2, Bases.canSteal(victim, victim, 1, 100)) == "own")
assert(select(2, Bases.canSteal(state(), victim, 3, 100)) == "empty")
assert(select(2, Bases.canSteal(state(), state({ lockedUntil = 160 }), 1, 100)) == "locked")
assert(select(2, Bases.canSteal(state(), state({ shieldUntil = 700 }), 1, 100)) == "locked")
assert(select(2, Bases.canSteal(state({ carryingEgg = true }), victim, 1, 100)) == "busy")
assert(select(2, Bases.canSteal(state({ stolen = {} }), victim, 1, 100)) == "busy")
assert(select(2, Bases.canSteal(state({ slots = 2 }), victim, 1, 100)) == "full")
assert(select(2, Bases.canSteal(state(), state({ beingStolen = { thief = 2 } }), 2, 100)) == "taken")
assert(Bases.canSteal(state(), state({ beingStolen = { thief = 2 } }), 1, 100))

-- Profile keeps the base between sessions
local fresh = Profile.new(Rules.StartCoins)
assert(#fresh.base == 0 and fresh.baseSlots == Bases.StartSlots)
local stored = Profile.new(50)
stored.owned = { [Rules.Vaults[1].pets[1].id] = true }
stored.base = { Rules.Vaults[1].pets[1].id, "not_a_pet", Rules.Vaults[1].pets[2].id }
stored.baseSlots = 5
stored.shieldUntil = 1234
stored.receipts = { "r1", 5 }
local petCatalog = {}
for _, vault in ipairs(Rules.Vaults) do
    for _, pet in ipairs(vault.pets) do
        petCatalog[pet.id] = pet
    end
end
local record = Profile.read(stored, petCatalog, Rules)
assert(record and record.baseSlots == 5 and #record.base == 2, "Unknown pets are dropped from the base")
assert(record.shieldUntil == 1234 and record.incomeBoostUntil == 0)
assert(#record.receipts == 1 and record.receipts[1] == "r1")
stored.baseSlots = 99
record = Profile.read(stored, petCatalog, Rules)
assert(record.baseSlots == Bases.StartSlots, "Invalid slot counts reset")
stored.baseSlots = 4
stored.base = { "dew_moth", "leaf_tail", "leaf_tail", "leaf_tail", "leaf_tail" }
record = Profile.read(stored, petCatalog, Rules)
assert(#record.base == 4, "Base never exceeds its slots")

local entry = { receipts = {} }
assert(Profile.rememberReceipt(entry, "x") and not Profile.rememberReceipt(entry, "x"))
for index = 1, 60 do
    Profile.rememberReceipt(entry, "r" .. index)
end
assert(#entry.receipts == 50 and entry.receipts[50] == "r60")

-- Every product has English text
for _, key in ipairs(Bases.ProductOrder) do
    local product = Bases.Products[key]
    assert(Locale.text("en", product.name) ~= product.name, "Missing English: " .. product.name)
    assert(Locale.text("en", product.description) ~= product.description)
end

print("Eggstride bases: OK")
