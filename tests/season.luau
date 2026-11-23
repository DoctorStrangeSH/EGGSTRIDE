local Rules = require("../src/shared/Rules")
local Profile = require("../src/server/Profile")
local Season = require("../src/server/Season")
local definition = Rules.Season

local entry = {
    coins = 15, tier = 1, onboarding = 1, materials = {}, ownedPets = {},
    deliveries = {}, prizeWins = {}, catalysts = {}, discoveries = {}, deliveryRecords = {},
}

assert(Season.rollover(entry, definition, 20))
assert(not Season.claim(entry, definition, 20, 1))
assert(not Season.claim(entry, definition, 20, 999))
assert(not Season.advance(entry, definition, 20, "unknown"))
assert(Season.advance(entry, definition, 20, "delivery"))
assert(Season.advance(entry, definition, 20, "delivery"))
assert(entry.season.xp == 0 and entry.season.counts.delivery == 2)
assert(Season.advance(entry, definition, 20, "delivery"))
assert(not Season.advance(entry, definition, 20, "delivery"))
assert(entry.season.xp == 30 and entry.season.counts.delivery == 3)
assert(Season.claim(entry, definition, 20, 1) and entry.coins == 55)
assert(not Season.claim(entry, definition, 20, 1) and entry.coins == 55)
assert(Season.advance(entry, definition, 20, "route"))
assert(Season.advance(entry, definition, 20, "route"))
assert(Season.claim(entry, definition, 20, 2) and entry.materials.meadow == 2)
assert(Season.advance(entry, definition, 20, "weekly"))
assert(not Season.advance(entry, definition, 20, "weekly"))
assert(entry.season.xp == 120)
assert(Season.advance(entry, definition, 21, "delivery"))
assert(entry.season.xp == 120 and entry.season.counts.delivery == 1 and not entry.season.counts.weekly)
assert(not Season.advance(entry, definition, 20, "delivery"))
assert(not Season.claim(entry, definition, 20, 3))
assert(not Season.claim(entry, definition, 21, 1))

for week = 21, 23 do
    for _, quest in ipairs(definition.quests) do
        for _ = 1, quest.goal do
            Season.advance(entry, definition, week, quest.id)
        end
    end
end
assert(entry.season.xp == 360)
assert(Season.claim(entry, definition, 23, 5))
local pet = Rules.SeasonPets[1]
assert(entry.ownedPets[pet.id] == pet)
assert(not Season.claim(entry, definition, 23, 5))

local snapshot = Profile.snapshot(entry)
Season.rollover(entry, definition, 24)
assert(snapshot.season.counts.delivery == 3 and snapshot.season.claimed["5"])
local restored = Profile.read(snapshot, { [pet.id] = pet }, Rules)
assert(restored.season.xp == 360 and restored.season.claimed["1"] and restored.season.claimed["5"])
assert(restored.owned[pet.id] and restored.materials.meadow == 2)
snapshot.season.counts.delivery = 999
snapshot.season.counts.route = "2"
snapshot.season.claimed["999"] = true
local filtered = Profile.read(snapshot, { [pet.id] = pet }, Rules)
assert(not filtered.season.counts.delivery and not filtered.season.counts.route and not filtered.season.claimed["999"])

snapshot.season.id = "old_season"
local oldSeason = Profile.read(snapshot, { [pet.id] = pet }, Rules)
assert(not oldSeason.season and oldSeason.owned[pet.id])
assert(not Profile.read(Profile.new(15), {}, Rules).season)

print("Eggstride season: OK")
