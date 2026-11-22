local Profile = require("../src/server/Profile")
local Rules = require("../src/shared/Rules")

local catalog = {}
for _, vault in ipairs(Rules.Vaults) do
    for _, pet in pairs(vault.pets) do
        catalog[pet.id] = pet
    end
end

local defaults = Profile.new(Rules.StartCoins)
assert(defaults.tier == 1 and defaults.coins == Rules.StartCoins and not next(defaults.owned) and defaults.onboarding == 0 and not defaults.stormTrailUnlocked)

local opened = Profile.acquire(nil, "server_a", 100, catalog, Rules)
assert(opened.lease.owner == "server_a" and opened.lease.expiresAt == 280)
local blocked, reason = Profile.acquire(opened, "server_b", 101, catalog, Rules)
assert(blocked == nil and reason == "locked")
assert(Profile.acquire(opened, "server_a", 101, catalog, Rules).lease.expiresAt == 281)

local pet = catalog.dew_moth
local entry = {
    coins = 77, tier = 2, ownedPets = { [pet.id] = pet }, pet = pet,
    onboarding = 3, stormTrailUnlocked = true, deliveryRecords = { meadow = 8420 }, delivered = true, egg = Rules.Vaults[1].eggs[1],
}
local snapshot = Profile.snapshot(entry)
assert(snapshot.coins == 77 and snapshot.tier == 2 and snapshot.equipped == pet.id and snapshot.onboarding == 3)
assert(snapshot.deliveryRecords.meadow == 8420)
assert(snapshot.owned[pet.id] == true and snapshot.egg == nil and snapshot.delivered == nil)
assert(Profile.write(opened, snapshot, "server_b", 101, false) == nil)

local interim = Profile.write(opened, snapshot, "server_a", 150, false)
assert(interim.lease.expiresAt == 330 and interim.coins == 77)
assert(Profile.write(interim, snapshot, "server_a", 330, false) == nil)
local takeover = Profile.acquire(interim, "server_b", 330, catalog, Rules)
assert(takeover.lease.owner == "server_b" and takeover.owned[pet.id] and takeover.equipped == pet.id)
assert(Profile.write(takeover, defaults, "server_a", 331, true) == nil)
local released = Profile.write(takeover, snapshot, "server_b", 331, true)
assert(released.lease == nil and released.owned[pet.id])
local rejoined = Profile.acquire(released, "server_c", 331, catalog, Rules)
assert(rejoined.equipped == pet.id and rejoined.coins == 77 and rejoined.tier == 2 and rejoined.onboarding == 3 and rejoined.stormTrailUnlocked)

assert(rejoined.deliveryRecords.meadow == 8420)
assert(not next(Profile.read({version = 1, coins = 15, tier = 1, owned = {}}, catalog, Rules).deliveryRecords))
snapshot.deliveryRecords.unknown = 5000
snapshot.deliveryRecords.amber = -1
local validatedRecords = Profile.read(snapshot, catalog, Rules).deliveryRecords
assert(validatedRecords.meadow == 8420 and validatedRecords.unknown == nil and validatedRecords.amber == nil)
snapshot.onboarding = nil
assert(Profile.read(snapshot, catalog, Rules).onboarding == 4)
local legacyNew = { version = Profile.VERSION, coins = 15, tier = 1, owned = {} }
assert(Profile.read(legacyNew, catalog, Rules).onboarding == 0)
assert(not Profile.read(legacyNew, catalog, Rules).stormTrailUnlocked)
snapshot.equipped = "unknown_pet"
snapshot.owned.unknown_pet = true
local normalized = Profile.read(snapshot, catalog, Rules)
assert(normalized.equipped == pet.id and normalized.owned.unknown_pet == nil)
snapshot.version = Profile.VERSION + 1
local invalid, invalidReason = Profile.acquire(snapshot, "server_c", 400, catalog, Rules)
assert(invalid == nil and invalidReason == "invalid")
assert(Profile.acquire({version = 1, coins = -1, tier = 1, owned = {}}, "server_c", 400, catalog, Rules) == nil)

print("Eggstride profiles: OK")
