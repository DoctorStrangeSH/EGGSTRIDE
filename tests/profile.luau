local Profile = require("../src/server/Profile")
local Rules = require("../src/shared/Rules")
local Loot = require("../src/server/Loot")

local catalog = {}
for _, vault in ipairs(Rules.Vaults) do
    for _, pet in ipairs(vault.pets) do
        catalog[pet.id] = pet
    end
end

for _, prize in ipairs(Rules.Prizes) do
    for _, pet in ipairs(prize.pets) do
        catalog[pet.id] = pet
    end
end

local Nursery = require("../src/server/Nursery")
local byPair, byOffspring = Nursery.recipes(Rules)
for id, recipe in pairs(byOffspring) do
    assert(not catalog[id])
    catalog[id] = recipe.offspring
end

for _, mutation in ipairs(Rules.Mutations) do
    catalog[mutation.pet.id] = mutation.pet
end

local defaults = Profile.new(Rules.StartCoins)
assert(defaults.tier == 1 and defaults.coins == Rules.StartCoins and not next(defaults.owned) and defaults.onboarding == 0 and not defaults.stormTrailUnlocked)

assert(defaults.muteRunSounds == false and defaults.reduceCardMotion == false)

local opened = Profile.acquire(nil, "server_a", 100, catalog, Rules)
assert(opened.lease.owner == "server_a" and opened.lease.expiresAt == 280)
local blocked, reason = Profile.acquire(opened, "server_b", 101, catalog, Rules)
assert(blocked == nil and reason == "locked")
assert(Profile.acquire(opened, "server_a", 101, catalog, Rules).lease.expiresAt == 281)

local pet = catalog.dew_moth
local entry = {
    deliveries = {}, prizeWins = {}, materials = {}, discoveries = {}, catalysts = {},
    coins = 77, tier = 2, weeklyRewardWeek = 20, muteRunSounds = true, reduceCardMotion = true, ownedPets = { [pet.id] = pet }, pet = pet,
    onboarding = 3, stormTrailUnlocked = true, deliveryRecords = { meadow = 8420 }, weeklyRecord = { week = 20, time = 14320, rankedTime = 15200, rankedSplits = { 2000, 4500, 6500, 9000, 12000, 15200 } }, delivered = true, egg = Loot.eggForRoll(1, 1),
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
assert(rejoined.weeklyRewardWeek == 20)
assert(Rules.claimWeeklyReward(rejoined, 20, Rules.Weekly.rewardTime, true) == nil and rejoined.coins == 77)
assert(rejoined.muteRunSounds == true and rejoined.reduceCardMotion == true)
assert(rejoined.weeklyRecord.week == 20 and rejoined.weeklyRecord.time == 14320
    and rejoined.weeklyRecord.rankedTime == 15200)
assert(rejoined.weeklyRecord.rankedSplits[3] == 6500 and rejoined.weeklyRecord.rankedSplits[6] == 15200)
snapshot.weeklyRecord.rankedSplits = { 2000, 4500, 4200, 9000, 12000, 15200 }
local badSplits = Profile.read(snapshot, catalog, Rules).weeklyRecord
assert(badSplits.rankedTime == 15200 and badSplits.rankedSplits == nil)
snapshot.weeklyRecord = { week = 20, time = 14320, rankedTime = 500 }
local invalidRanked = Profile.read(snapshot, catalog, Rules).weeklyRecord
assert(invalidRanked.time == 14320 and invalidRanked.rankedTime == nil)
assert(not next(Profile.read({version = 1, coins = 15, tier = 1, owned = {}}, catalog, Rules).deliveryRecords))
snapshot.deliveryRecords.unknown = 5000
snapshot.deliveryRecords.amber = -1
snapshot.weeklyRecord = { week = 20, time = 999999 }
assert(Profile.read(snapshot, catalog, Rules).weeklyRecord == nil)
local validatedRecords = Profile.read(snapshot, catalog, Rules).deliveryRecords
assert(validatedRecords.meadow == 8420 and validatedRecords.unknown == nil and validatedRecords.amber == nil)
snapshot.onboarding = nil
assert(Profile.read(snapshot, catalog, Rules).onboarding == 4)
local legacyNew = { version = Profile.VERSION, coins = 15, tier = 1, owned = {} }
assert(Profile.read(legacyNew, catalog, Rules).onboarding == 0)
assert(not Profile.read(legacyNew, catalog, Rules).stormTrailUnlocked)
local legacyProfile = Profile.read(legacyNew, catalog, Rules)
assert(legacyProfile.muteRunSounds == false and legacyProfile.reduceCardMotion == false)
snapshot.muteRunSounds = "true"
snapshot.reduceCardMotion = 1
local sanitized = Profile.read(snapshot, catalog, Rules)
assert(sanitized.muteRunSounds == false and sanitized.reduceCardMotion == false)
snapshot.equipped = "unknown_pet"
snapshot.owned.unknown_pet = true
snapshot.weeklyRewardWeek = -1
local normalized = Profile.read(snapshot, catalog, Rules)
assert(normalized.weeklyRewardWeek == nil)
assert(normalized.equipped == pet.id and normalized.owned.unknown_pet == nil)
snapshot.version = Profile.VERSION + 1
local invalid, invalidReason = Profile.acquire(snapshot, "server_c", 400, catalog, Rules)
assert(invalid == nil and invalidReason == "invalid")
assert(Profile.acquire({version = 1, coins = -1, tier = 1, owned = {}}, "server_c", 400, catalog, Rules) == nil)

local relic = Rules.Prizes[3].pets[5]
assert(not next(legacyProfile.deliveries) and not next(legacyProfile.prizeWins) and not next(legacyProfile.materials))
local meadow, storm = Rules.Vaults[1], Rules.Vaults[3]
local isNew, gain = Profile.recordHatch(entry, meadow, meadow.pets[1])
assert(isNew and gain == 0 and entry.ownedPets[meadow.pets[1].id] == meadow.pets[1])
isNew, gain = Profile.recordHatch(entry, meadow, meadow.pets[1])
assert(not isNew and gain == 1 and entry.deliveries.meadow == 2 and entry.materials.meadow == 1)
assert(not next(entry.prizeWins))
isNew, gain = Profile.recordHatch(entry, storm, relic, Rules.Prizes[3].id)
assert(isNew and gain == 0)
isNew, gain = Profile.recordHatch(entry, storm, relic, Rules.Prizes[3].id)
assert(not isNew and gain == 1 and entry.deliveries.storm == 2 and entry.prizeWins.storm == 2)
entry.pet = relic
local progressSnapshot = Profile.snapshot(entry)
local savedProgress = Profile.write(opened, progressSnapshot, "server_a", 180, true)
local relicProfile = Profile.acquire(savedProgress, "server_d", 181, catalog, Rules)
assert(relicProfile.deliveries.meadow == 2 and relicProfile.deliveries.storm == 2)
assert(relicProfile.prizeWins.storm == 2 and relicProfile.materials.meadow == 1 and relicProfile.materials.storm == 1)
assert(relicProfile.equipped == relic.id and relicProfile.owned[relic.id])

Profile.recordHatch(entry, storm, relic, "storm")
assert(progressSnapshot.deliveries.storm == 2 and progressSnapshot.prizeWins.storm == 2 and progressSnapshot.materials.storm == 1)
progressSnapshot.deliveries.unknown = 50
progressSnapshot.deliveries.amber = 1.5
progressSnapshot.prizeWins.unknown = 1
progressSnapshot.prizeWins.amber = -1
progressSnapshot.materials.storm = "50"
local cleanProgress = Profile.read(progressSnapshot, catalog, Rules)
assert(cleanProgress.deliveries.meadow == 2 and not cleanProgress.deliveries.unknown and not cleanProgress.deliveries.amber)
assert(cleanProgress.prizeWins.storm == 2 and not cleanProgress.prizeWins.unknown and not cleanProgress.prizeWins.amber)
assert(cleanProgress.materials.meadow == 1 and not cleanProgress.materials.storm)

for _, recipe in pairs(byOffspring) do
    local vaultId = recipe.vault.id
    local offspringId = recipe.offspring.id
    local common = recipe.parents[1]
    local rare = recipe.parents[2]
    local breeder = {
        materials = { [vaultId] = recipe.cost },
        discoveries = {},
        ownedPets = { [common.id] = common },
    }
    assert(not Profile.breed(breeder, recipe))
    assert(breeder.materials[vaultId] == recipe.cost and not breeder.ownedPets[offspringId])

    breeder.ownedPets[rare.id] = rare
    breeder.materials[vaultId] = recipe.cost - 1
    assert(not Profile.breed(breeder, recipe))
    assert(breeder.materials[vaultId] == recipe.cost - 1 and not breeder.ownedPets[offspringId])

    breeder.materials[vaultId] = recipe.cost + 1
    assert(Profile.breed(breeder, recipe))
    assert(breeder.ownedPets[common.id] == common and breeder.ownedPets[rare.id] == rare)
    assert(breeder.materials[vaultId] == 1 and breeder.ownedPets[offspringId] == recipe.offspring)
    breeder.materials[vaultId] = recipe.cost
    assert(not Profile.breed(breeder, recipe) and breeder.materials[vaultId] == recipe.cost)
end

local recipe = byOffspring.bloom_moth
entry.ownedPets[recipe.parents[1].id] = recipe.parents[1]
entry.ownedPets[recipe.parents[2].id] = recipe.parents[2]
entry.materials[recipe.vault.id] = recipe.cost + 1
local previousDeliveries = entry.deliveries[recipe.vault.id]
assert(Profile.breed(entry, recipe))
entry.pet = recipe.offspring
local breedingSave = Profile.write(opened, Profile.snapshot(entry), "server_a", 182, true)
local breedingProfile = Profile.acquire(breedingSave, "server_e", 183, catalog, Rules)
assert(breedingProfile.owned[recipe.offspring.id] and breedingProfile.equipped == recipe.offspring.id)
assert(breedingProfile.materials[recipe.vault.id] == 1 and breedingProfile.deliveries[recipe.vault.id] == previousDeliveries)

assert(breedingProfile.discoveries[recipe.offspring.id])
local legacyStorage = Profile.snapshot(entry)
legacyStorage.discoveries = nil
legacyStorage.owned.cloud_lynx = true
local legacyNursery = Profile.read(legacyStorage, catalog, Rules)
assert(legacyNursery.discoveries.bloom_moth and legacyNursery.owned.cloud_lynx and not legacyNursery.discoveries.cloud_lynx)

local oldRelic = byOffspring.cloud_lynx
local collector = { materials = {}, discoveries = {}, ownedPets = { cloud_lynx = oldRelic.offspring } }
for _, parent in ipairs(oldRelic.parents) do
    collector.ownedPets[parent.id] = parent
end
assert(Profile.breed(collector, oldRelic) and not next(collector.materials))
assert(collector.discoveries.cloud_lynx and not Profile.breed(collector, oldRelic))
assert(Nursery.find(byPair, "leaf_tail", "dew_moth") == recipe)
assert(Nursery.find(byPair, "dew_moth", "leaf_tail") == recipe)
assert(not Nursery.find(byPair, "leaf_tail", "amber_crab"))
assert(not Nursery.find(byPair, "leaf_tail", "clover_hare"))

local mutation = Rules.Mutations[1]
local vault = mutation.vault
assert(not next(legacyNursery.catalysts))
assert(not Profile.awardCatalyst(entry, vault, 0) and not Profile.awardCatalyst(entry, vault, 1))
assert(not Profile.awardCatalyst(entry, vault, nil) and not next(entry.catalysts))
assert(Profile.awardCatalyst(entry, Rules.Vaults[2], 2))
assert(not Profile.mutatePet(entry, mutation))
assert(entry.catalysts.amber == 1)

assert(Profile.awardCatalyst(entry, vault, 2) and not Profile.mutatePet(entry, mutation))
assert(Profile.awardCatalyst(entry, vault, 2))
entry.ownedPets[mutation.parent.id] = nil
assert(not Profile.mutatePet(entry, mutation) and entry.catalysts.meadow == 2)
entry.ownedPets[mutation.parent.id] = mutation.parent
assert(Profile.mutatePet(entry, mutation))
assert(entry.ownedPets[mutation.parent.id] and entry.ownedPets[mutation.pet.id] and entry.catalysts.meadow == 0)
assert(Profile.awardCatalyst(entry, vault, 2) and Profile.awardCatalyst(entry, vault, 2))
assert(not Profile.mutatePet(entry, mutation) and entry.catalysts.meadow == 2)
entry.pet = mutation.pet
local mutationSnapshot = Profile.snapshot(entry)
mutationSnapshot.catalysts.storm = -1
mutationSnapshot.catalysts.unknown = 5
local mutationSave = Profile.write(opened, mutationSnapshot, "server_a", 190, true)
local mutationProfile = Profile.acquire(mutationSave, "server_f", 191, catalog, Rules)
assert(mutationProfile.equipped == mutation.pet.id and mutationProfile.owned[mutation.parent.id])
assert(mutationProfile.catalysts.meadow == 2 and mutationProfile.catalysts.amber == 1)
assert(not mutationProfile.catalysts.storm and not mutationProfile.catalysts.unknown)

print("Eggstride profiles: OK")
