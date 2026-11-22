local Profile = {}

Profile.VERSION = 1
Profile.LEASE_SECONDS = 180

function Profile.new(startCoins)
    return { version = Profile.VERSION, coins = startCoins, tier = 1, owned = {}, equipped = nil }
end

local function wholeNumber(value, low, high)
    return type(value) == "number" and value >= low and value <= high and value % 1 == 0
end

function Profile.read(stored, catalog, maxTier)
    if type(stored) ~= "table" or stored.version ~= Profile.VERSION
        or not wholeNumber(stored.coins, 0, 9e15) or not wholeNumber(stored.tier, 1, maxTier)
        or type(stored.owned) ~= "table" then
        return nil
    end

    local record = Profile.new(stored.coins)
    record.tier = stored.tier
    for id, owned in pairs(stored.owned) do
        if owned == true and catalog[id] then
            record.owned[id] = true
        end
    end
    if type(stored.equipped) == "string" and record.owned[stored.equipped] then
        record.equipped = stored.equipped
    else
        record.equipped = next(record.owned)
    end
    return record
end

function Profile.snapshot(entry)
    local record = Profile.new(entry.coins)
    record.tier = entry.tier
    for id in pairs(entry.ownedPets) do
        record.owned[id] = true
    end
    record.equipped = entry.pet and entry.pet.id or nil
    return record
end

function Profile.acquire(stored, owner, now, catalog, maxTier, startCoins)
    local record
    if stored == nil then
        record = Profile.new(startCoins)
    else
        record = Profile.read(stored, catalog, maxTier)
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
