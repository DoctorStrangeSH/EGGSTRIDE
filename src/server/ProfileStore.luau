local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Profile = require(script.Parent.Profile)

local ProfileStore = {}
local store
if not RunService:IsStudio() then
    store = DataStoreService:GetDataStore("EggstrideProfiles_v1")
elseif workspace:GetAttribute("UseStudioDataStore") == true then
    store = DataStoreService:GetDataStore("EggstrideStudioProfiles_v1")
end

function ProfileStore.open(player, catalog, rules, canContinue)
    if not store then
        return {}, Profile.new(rules.StartCoins)
    end

    local session = {
        key = "player_" .. player.UserId,
        owner = HttpService:GenerateGUID(false),
        busy = false,
    }
    for attempt = 1, 5 do
        if not canContinue() then
            return nil, nil, "left"
        end
        local reason
        local ok, record = pcall(function()
            return store:UpdateAsync(session.key, function(stored)
                local updated
                updated, reason = Profile.acquire(stored, session.owner, os.time(), catalog, rules)
                return updated
            end)
        end)
        if ok and not reason and record then
            session.expiresAt = record.lease.expiresAt
            return session, record
        end
        if ok and reason == "invalid" then
            return nil, nil, reason
        end
        if attempt < 5 then
            task.wait(attempt)
        end
    end
    return nil, nil, "unavailable"
end

function ProfileStore.expired(session)
    return session.expiresAt ~= nil and os.time() >= session.expiresAt
end

function ProfileStore.save(session, record, release)
    if not store then
        return true
    end
    if release then
        while session.busy do
            task.wait()
        end
    elseif session.busy then
        return true
    end

    session.busy = true
    for attempt = 1, 3 do
        local accepted
        local ok, saved = pcall(function()
            return store:UpdateAsync(session.key, function(stored)
                local updated = Profile.write(stored, record, session.owner, os.time(), release)
                accepted = updated ~= nil
                return updated
            end)
        end)
        if ok then
            session.busy = false
            if not accepted or not saved then
                session.expiresAt = 0
                return false, "lost"
            end
            if not release then
                session.expiresAt = saved.lease.expiresAt
            end
            return true
        end
        if attempt < 3 then
            task.wait(attempt)
        end
    end
    session.busy = false
    return false, "unavailable"
end

return ProfileStore
