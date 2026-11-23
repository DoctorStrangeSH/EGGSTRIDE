local Profile = require("../src/server/Profile")
local Rules = require("../src/shared/Rules")
local TrailShop = require("../src/server/TrailShop")

local attrs = { TrailPass_mint = 123, TrailPass_ember = 456, TrailPass_aurora = 789 }
local function getAttribute(name)
    return attrs[name]
end
local passes = TrailShop.passes(Rules.Trails, getAttribute, 999)
assert(passes.mint == 123 and passes.ember == 456 and passes.aurora == 789)
attrs.TrailPass_ember = 123
passes = TrailShop.passes(Rules.Trails, getAttribute, 789)
assert(not next(passes), "Duplicate and season pass IDs must not be offered")
attrs.TrailPass_ember = 1.5
attrs.TrailPass_aurora = "789"
passes = TrailShop.passes(Rules.Trails, getAttribute, 999)
assert(passes.mint == 123 and not passes.ember and not passes.aurora)

local entry = {
    coins = 30, tier = 2, trailPreview = "aurora", trailStatuses = { mint = "owned" },
    materials = {}, ownedPets = {}, deliveries = {}, prizeWins = {},
    catalysts = {}, discoveries = {}, deliveryRecords = {},
}
assert(not TrailShop.select(entry, "aurora", false) and not entry.equippedTrail)
assert(TrailShop.select(entry, "mint", true))
assert(not TrailShop.select(entry, "ember", false) and entry.equippedTrail == "mint")
local snapshot = Profile.snapshot(entry)
assert(not snapshot.trailPreview and not snapshot.trailStatuses)
local reopened = Profile.read(snapshot, {}, Rules)
assert(reopened.equippedTrail == "mint" and reopened.coins == 30 and reopened.tier == 2)
assert(not reopened.trailStatuses)
assert(TrailShop.select(entry, "", false) and not entry.equippedTrail)
snapshot.equippedTrail = "invalid"
assert(not Profile.read(snapshot, {}, Rules).equippedTrail)
assert(not Profile.read(Profile.new(15), {}, Rules).equippedTrail)

print("Eggstride trail shop: OK")
