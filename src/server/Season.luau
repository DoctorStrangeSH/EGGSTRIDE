local Season = {}

function Season.rollover(entry, definition, week)
    local progress = entry.season
    if not progress or progress.id ~= definition.id then
        entry.season = { id = definition.id, week = week, xp = 0, counts = {}, claimed = {}, deliveryBests = {} }
    elseif week > progress.week then
        progress.week = week
        table.clear(progress.counts)
        table.clear(progress.deliveryBests)
    else
        return false
    end
    return true
end

function Season.advance(entry, definition, week, activity)
    local changed = Season.rollover(entry, definition, week)
    local progress = entry.season
    if progress.week ~= week then
        return changed
    end
    for _, quest in ipairs(definition.quests) do
        if quest.id == activity then
            local count = progress.counts[activity] or 0
            if count >= quest.goal then
                return changed
            end
            count += 1
            progress.counts[activity] = count
            if count == quest.goal then
                local maximum = definition.rewards[#definition.rewards].xp
                progress.xp = math.min(maximum, progress.xp + quest.xp)
            end
            return true
        end
    end
    return changed
end

function Season.recordDelivery(entry, rules, week, vault, elapsed)
    local changed = Season.rollover(entry, rules.Season, week)
    local progress = entry.season
    if progress.week ~= week then
        return changed
    end

    local previous = progress.deliveryBests[vault.id]
    local milliseconds = rules.improvedDelivery(nil, elapsed)
    local best = milliseconds and math.max(10, math.round(milliseconds / 10) * 10)
    if not best or (previous and best >= previous) then
        return changed
    end
    progress.deliveryBests[vault.id] = best
    if previous then
        local before = progress.xp
        Season.advance(entry, rules.Season, week, "record")
        return true, before < progress.xp and progress.xp - before or nil
    end
    return true
end

function Season.claim(entry, definition, week, index, premium)
    local rolledOver = Season.rollover(entry, definition, week)
    local progress = entry.season
    local rewards = if premium then definition.premiumRewards else definition.rewards
    local reward = rewards[index]
    local key = if premium then "premium_" .. index else tostring(index)
    if (premium and not entry.seasonPremium) or progress.week ~= week or not reward or progress.claimed[key] or progress.xp < reward.xp then
        return false, rolledOver
    end

    local maximum = 9e15
    if reward.coins and entry.coins > maximum - reward.coins then
        return false, rolledOver
    end
    if reward.material then
        local stock = entry.materials[reward.material] or 0
        if stock > maximum - reward.amount then
            return false, rolledOver
        end
        entry.materials[reward.material] = stock + reward.amount
    elseif reward.coins then
        entry.coins += reward.coins
    elseif reward.pet then
        entry.ownedPets[reward.pet.id] = reward.pet
    end
    progress.claimed[key] = true
    return true
end

return Season
