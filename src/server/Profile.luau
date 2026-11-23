local Profile = {}

Profile.VERSION = 1
Profile.LEASE_SECONDS = 180
local MAX_COUNTER = 9e15

function Profile.new(startCoins)
    return {
        version = Profile.VERSION, coins = startCoins, tier = 1, owned = {},
        equipped = nil, onboarding = 0, stormTrailUnlocked = false, deliveryRecords = {},
        muteRunSounds = false, reduceCardMotion = false,
        deliveries = {}, prizeWins = {}, materials = {}, discoveries = {}, catalysts = {},
    }
end

local function wholeNumber(value, low, high)
    return type(value) == "number" and value >= low and value <= high and value % 1 == 0
end

local function readCounts(stored, definitions)
    local counts = {}
    if type(stored) == "table" then
        for _, definition in ipairs(definitions) do
            local count = stored[definition.id]
            if wholeNumber(count, 1, MAX_COUNTER) then
                counts[definition.id] = count
            end
        end
    end
    return counts
end

local function increment(counts, id)
    counts[id] = math.min((counts[id] or 0) + 1, MAX_COUNTER)
end

function Profile.recordHatch(entry, vault, pet, prizeId)
    increment(entry.deliveries, vault.id)
    if prizeId then
        increment(entry.prizeWins, prizeId)
    end

    local isNew = entry.ownedPets[pet.id] == nil
    local materialGain = 0
    if isNew then
        entry.ownedPets[pet.id] = pet
    elseif (entry.materials[vault.id] or 0) < MAX_COUNTER then
        increment(entry.materials, vault.id)
        materialGain = 1
    end
    return isNew, materialGain
end

function Profile.breed(entry, recipe)
    local pet = recipe.offspring
    local parents = recipe.parents
    local vaultId = recipe.vault.id
    local stock = entry.materials[vaultId] or 0
    if entry.discoveries[pet.id] or not entry.ownedPets[parents[1].id]
        or not entry.ownedPets[parents[2].id] then
        return false
    end
    if not entry.ownedPets[pet.id] then
        if stock < recipe.cost then
            return false
        end
        entry.materials[vaultId] = stock - recipe.cost
        entry.ownedPets[pet.id] = pet
    end
    entry.discoveries[pet.id] = true
    return true
end

function Profile.awardCatalyst(entry, vault, routeStage)
    if routeStage ~= 2 or (entry.catalysts[vault.id] or 0) >= MAX_COUNTER then
        return false
    end
    increment(entry.catalysts, vault.id)
    return true
end

function Profile.mutatePet(entry, mutation)
    local id = mutation.vault.id
    local stock = entry.catalysts[id] or 0
    if not entry.ownedPets[mutation.parent.id] or entry.ownedPets[mutation.pet.id]
        or stock < mutation.cost then
        return false
    end
    entry.catalysts[id] = stock - mutation.cost
    entry.ownedPets[mutation.pet.id] = mutation.pet
    return true
end

local function readSeason(stored, rules)
    local definition = rules.Season
    local lastReward = definition.rewards[#definition.rewards]
    if type(stored) ~= "table" or stored.id ~= definition.id
        or not wholeNumber(stored.week, 0, MAX_COUNTER)
        or not wholeNumber(stored.xp, 0, lastReward.xp) then
        return nil
    end

    local season = { id = definition.id, week = stored.week, xp = stored.xp, counts = {}, claimed = {} }
    season.deliveryBests = {}
    if type(stored.deliveryBests) == "table" then
        for _, vault in ipairs(rules.Vaults) do
            local time = stored.deliveryBests[vault.id]
            if wholeNumber(time, 1, rules.RunSeconds * 1000) then
                season.deliveryBests[vault.id] = time
            end
        end
    end
    if type(stored.counts) == "table" then
        for _, quest in ipairs(definition.quests) do
            local count = stored.counts[quest.id]
            if wholeNumber(count, 1, quest.goal) then
                season.counts[quest.id] = count
            end
        end
    end
    if type(stored.claimed) == "table" then
        for index, reward in ipairs(definition.rewards) do
            local key = tostring(index)
            if stored.claimed[key] == true and season.xp >= reward.xp then
                season.claimed[key] = true
            end
        end
        for index, reward in ipairs(definition.premiumRewards) do
            local key = "premium_" .. index
            if stored.claimed[key] == true and season.xp >= reward.xp then
                season.claimed[key] = true
            end
        end
    end
    return season
end

function Profile.read(stored, catalog, rules)
    if type(stored) ~= "table" or stored.version ~= Profile.VERSION
        or not wholeNumber(stored.coins, 0, 9e15) or not wholeNumber(stored.tier, 1, #rules.Speeds)
        or type(stored.owned) ~= "table" then
        return nil
    end

    local record = Profile.new(stored.coins)
    for _, trail in ipairs(rules.Trails) do
        if stored.equippedTrail == trail.id then
            record.equippedTrail = trail.id
            break
        end
    end
    for _, effect in ipairs(rules.HatchEffects) do
        if stored.equippedHatchEffect == effect.id then
            record.equippedHatchEffect = effect.id
            break
        end
    end
    for _, theme in ipairs(rules.CampThemes) do
        if stored.equippedCampTheme == theme.id then
            record.equippedCampTheme = theme.id
            break
        end
    end
    record.tier = stored.tier
    record.season = readSeason(stored.season, rules)
    record.deliveries = readCounts(stored.deliveries, rules.Vaults)
    record.prizeWins = readCounts(stored.prizeWins, rules.Prizes)
    record.materials = readCounts(stored.materials, rules.Vaults)
    record.catalysts = readCounts(stored.catalysts, rules.Vaults)
    record.muteRunSounds = stored.muteRunSounds == true
    record.reduceCardMotion = stored.reduceCardMotion == true
    record.stormTrailUnlocked = stored.stormTrailUnlocked == true
    if type(stored.deliveryRecords) == "table" then
        for _, vault in ipairs(rules.Vaults) do
            local time = stored.deliveryRecords[vault.id]
            if wholeNumber(time, 1, rules.RunSeconds * 1000) then
                record.deliveryRecords[vault.id] = time
            end
        end
    end
    if wholeNumber(stored.weeklyRewardWeek, 0, 9e15) then
        record.weeklyRewardWeek = stored.weeklyRewardWeek
    end
    local weekly = stored.weeklyRecord
    if type(weekly) == "table" and wholeNumber(weekly.week, 0, 9e15)
        and wholeNumber(weekly.time, 1, rules.Weekly.duration * 1000) then
        record.weeklyRecord = { week = weekly.week, time = weekly.time }
        if wholeNumber(weekly.rankedTime, weekly.time, rules.Weekly.duration * 1000) then
            record.weeklyRecord.rankedTime = weekly.rankedTime
        end
    end
    if record.weeklyRecord and record.weeklyRecord.rankedTime and type(weekly.rankedSplits) == "table" then
        local splits = {}
        local previous = 0
        for index = 1, #rules.Weekly.order do
            local time = weekly.rankedSplits[index]
            if not wholeNumber(time, previous + 1, rules.Weekly.duration * 1000) then
                break
            end
            splits[index] = time
            previous = time
        end
        if #splits == #rules.Weekly.order and previous >= record.weeklyRecord.rankedTime then
            record.weeklyRecord.rankedSplits = splits
        end
    end
    for id, owned in pairs(stored.owned) do
        if owned == true and catalog[id] then
            record.owned[id] = true
        end
    end
    for _, offspring in ipairs(rules.Offspring) do
        for index, pet in ipairs(offspring) do
            if record.owned[pet.id] and ((type(stored.discoveries) == "table" and stored.discoveries[pet.id] == true)
                or (stored.discoveries == nil and index == 1)) then
                record.discoveries[pet.id] = true
            end
        end
    end
    if type(stored.equipped) == "string" and record.owned[stored.equipped] then
        record.equipped = stored.equipped
    else
        record.equipped = next(record.owned)
    end
    if wholeNumber(stored.onboarding, 0, 4) then
        record.onboarding = stored.onboarding
    elseif next(record.owned) then
        record.onboarding = 4
    end
    return record
end

function Profile.snapshot(entry)
    local record = Profile.new(entry.coins)
    record.tier = entry.tier
    record.equippedTrail = entry.equippedTrail
    record.equippedHatchEffect = entry.equippedHatchEffect
    record.equippedCampTheme = entry.equippedCampTheme
    record.muteRunSounds = entry.muteRunSounds == true
    record.reduceCardMotion = entry.reduceCardMotion == true
    record.stormTrailUnlocked = entry.stormTrailUnlocked == true
    record.deliveryRecords = table.clone(entry.deliveryRecords)
    record.deliveries = table.clone(entry.deliveries)
    record.prizeWins = table.clone(entry.prizeWins)
    record.materials = table.clone(entry.materials)
    record.catalysts = table.clone(entry.catalysts)
    record.discoveries = table.clone(entry.discoveries)
    local season = entry.season
    if season then
        record.season = {
            id = season.id, week = season.week, xp = season.xp,
            counts = table.clone(season.counts), claimed = table.clone(season.claimed),
            deliveryBests = table.clone(season.deliveryBests),
        }
    end
    record.weeklyRecord = entry.weeklyRecord
    record.weeklyRewardWeek = entry.weeklyRewardWeek
    record.onboarding = entry.onboarding
    for id in pairs(entry.ownedPets) do
        record.owned[id] = true
    end
    record.equipped = entry.pet and entry.pet.id or nil
    return record
end

function Profile.acquire(stored, owner, now, catalog, rules)
    local record
    if stored == nil then
        record = Profile.new(rules.StartCoins)
    else
        record = Profile.read(stored, catalog, rules)
        if not record then
            return nil, "invalid"
        end
        local lease = stored.lease
        if lease ~= nil then
            if type(lease) ~= "table" or type(lease.owner) ~= "string"
                or not wholeNumber(lease.expiresAt, 0, 9e15) then
                return nil, "invalid"
            end
            if lease.owner ~= owner and lease.expiresAt > now then
                return nil, "locked"
            end
        end
    end
    record.lease = { owner = owner, expiresAt = now + Profile.LEASE_SECONDS }
    return record
end

function Profile.write(stored, snapshot, owner, now, release)
    local lease = type(stored) == "table" and stored.lease
    if type(lease) ~= "table" or lease.owner ~= owner or type(lease.expiresAt) ~= "number"
        or lease.expiresAt <= now or stored.version ~= Profile.VERSION then
        return nil
    end

    local record = table.clone(snapshot)
    if not release then
        record.lease = { owner = owner, expiresAt = now + Profile.LEASE_SECONDS }
    end
    return record
end

return Profile
