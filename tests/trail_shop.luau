local Profile = require("../src/server/Profile")
local Rules = require("../src/shared/Rules")
local CosmeticShop = require("../src/server/CosmeticShop")

local mint, ember, aurora = table.unpack(Rules.Trails)
local petals = Rules.HatchEffects[1]
local sunrise = Rules.CampThemes[1]

local attrs = { TrailPass_mint = 123, TrailPass_ember = 456, TrailPass_aurora = 789 }
local function getAttribute(name)
    return attrs[name]
end
local passes = CosmeticShop.passes(Rules.Trails, getAttribute, 999)
assert(passes.mint == 123 and passes.ember == 456 and passes.aurora == 789)
attrs.TrailPass_ember = 123
passes = CosmeticShop.passes(Rules.Trails, getAttribute, 789)
assert(not next(passes), "Duplicate and season pass IDs must not be offered")
attrs.TrailPass_ember = 1.5
attrs.TrailPass_aurora = "789"
passes = CosmeticShop.passes(Rules.Trails, getAttribute, 999)
assert(passes.mint == 123 and not passes.ember and not passes.aurora)

local entry = {
    coins = 30, tier = 2, trailPreview = "aurora", cosmeticStatuses = { mint = "owned" },
    materials = {}, ownedPets = {}, deliveries = {}, prizeWins = {},
    catalysts = {}, discoveries = {}, deliveryRecords = {},
}
assert(not CosmeticShop.select(entry, aurora, false) and not entry.equippedTrail)
assert(CosmeticShop.select(entry, mint, true))
assert(not CosmeticShop.select(entry, ember, false) and entry.equippedTrail == "mint")
assert(not CosmeticShop.select(entry, petals, false) and not entry.equippedHatchEffect)
assert(CosmeticShop.select(entry, petals, true) and entry.equippedTrail == "mint")
assert(not CosmeticShop.select(entry, sunrise, false) and not entry.equippedCampTheme)
assert(CosmeticShop.select(entry, sunrise, true))
assert(entry.equippedTrail == mint.id and entry.equippedHatchEffect == petals.id)
local snapshot = Profile.snapshot(entry)
assert(not snapshot.trailPreview and not snapshot.cosmeticStatuses)
local reopened = Profile.read(snapshot, {}, Rules)
assert(reopened.equippedTrail == "mint" and reopened.coins == 30 and reopened.tier == 2)
assert(not reopened.cosmeticStatuses and reopened.equippedHatchEffect == "petals")
assert(reopened.equippedCampTheme == sunrise.id)
assert(CosmeticShop.select(entry, sunrise, true, true) and not entry.equippedCampTheme)
assert(entry.equippedTrail == mint.id and entry.equippedHatchEffect == petals.id)
snapshot.equippedCampTheme = mint.id
assert(not Profile.read(snapshot, {}, Rules).equippedCampTheme)
assert(not Profile.read(Profile.new(15), {}, Rules).equippedCampTheme)
assert(CosmeticShop.select(entry, mint, true, true) and not entry.equippedTrail)
assert(entry.equippedHatchEffect == "petals")
snapshot.equippedTrail = "invalid"
snapshot.equippedHatchEffect = "mint"
assert(not Profile.read(snapshot, {}, Rules).equippedHatchEffect)
assert(not Profile.read(snapshot, {}, Rules).equippedTrail)
assert(not Profile.read(Profile.new(15), {}, Rules).equippedTrail)

local combined = table.clone(Rules.Trails)
table.insert(combined, petals)
table.insert(combined, sunrise)
attrs.HatchPass_petals = 123
passes = CosmeticShop.passes(combined, getAttribute, 999)
assert(not passes.mint and not passes.petals)
attrs.HatchPass_petals = 1001
passes = CosmeticShop.passes(combined, getAttribute, 999)
assert(passes.mint == 123 and passes.petals == 1001)
assert(not CosmeticShop.passes(combined, getAttribute, 1001).petals)

attrs.CampPass_sunrise = attrs.HatchPass_petals
passes = CosmeticShop.passes(combined, getAttribute, 999)
assert(not passes.sunrise and not passes.petals and passes.mint == 123)
attrs.CampPass_sunrise = 1002
assert(CosmeticShop.passes(combined, getAttribute, 999).sunrise == 1002)
assert(not CosmeticShop.passes(combined, getAttribute, 1002).sunrise)

print("Eggstride cosmetic shop: OK")
