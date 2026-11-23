local PlaytestReport = {}
PlaytestReport.__index = PlaytestReport

local FIRST_DELIVERY_TARGET = 120

function PlaytestReport.new(vaults, windEnabled)
    local biomes = {}
    for _, vault in ipairs(vaults) do
        biomes[vault.id] = {
            pickups = 0, delivered = 0, timeout = 0, fall = 0, respawn = 0, left = 0,
            shortcutDeliveries = 0, prizePickups = 0, prizeDelivered = 0, prizeClaimMisses = 0,
            deliverySecondsTotal = 0, secondsLeftTotal = 0,
        }
    end
    return setmetatable({
        sessions = {},
        totals = {
            windEnabled = windEnabled, sessionsStarted = 0, sessionsEnded = 0,
            freshSessions = 0, freshSessionsEnded = 0, freshFirstPickups = 0, freshFirstDeliveries = 0,
            freshDeliveriesWithin120s = 0, freshRepeatPickups = 0,
            freshUpgrades = {
                amber = { count = 0, secondsTotal = 0 },
                storm = { count = 0, secondsTotal = 0 },
            },
            biomes = biomes,
        },
    }, PlaytestReport)
end

function PlaytestReport:join(player, now, fresh)
    self.sessions[player] = { startedAt = now, fresh = fresh }
    self.totals.sessionsStarted += 1
    if fresh then
        self.totals.freshSessions += 1
    end
end

function PlaytestReport:pickUp(player, biome, prize, now)
    local session = self.sessions[player]
    local stats = self.totals.biomes[biome]
    session.carrying = { biome = biome, prize = prize, pickedUpAt = now }
    stats.pickups += 1
    if prize then
        stats.prizePickups += 1
    end
    if session.fresh then
        if not session.pickedUp then
            session.pickedUp = true
            self.totals.freshFirstPickups += 1
        elseif session.delivered and not session.repeated then
            session.repeated = true
            self.totals.freshRepeatPickups += 1
        end
    end
end

function PlaytestReport:finish(player, outcome, now, secondsLeft, usedShortcut)
    local session = self.sessions[player]
    local cargo = session and session.carrying
    if not cargo then
        return
    end
    session.carrying = nil
    local stats = self.totals.biomes[cargo.biome]
    stats[outcome] += 1
    if outcome ~= "delivered" then
        return
    end

    stats.deliverySecondsTotal += now - cargo.pickedUpAt
    stats.secondsLeftTotal += secondsLeft
    if usedShortcut then
        stats.shortcutDeliveries += 1
    end
    if cargo.prize then
        stats.prizeDelivered += 1
    end
    if session.fresh and not session.delivered then
        session.delivered = true
        self.totals.freshFirstDeliveries += 1
        if now - session.startedAt <= FIRST_DELIVERY_TARGET then
            self.totals.freshDeliveriesWithin120s += 1
        end
    end
end

function PlaytestReport:upgrade(player, biome, now)
    local session = self.sessions[player]
    local stats = self.totals.freshUpgrades[biome]
    if session.fresh and stats then
        stats.count += 1
        stats.secondsTotal += now - session.startedAt
    end
end

function PlaytestReport:missPrize(biome)
    self.totals.biomes[biome].prizeClaimMisses += 1
end

function PlaytestReport:leave(player)
    local session = self.sessions[player]
    if not session then
        return
    end
    self:finish(player, "left")
    self.sessions[player] = nil
    self.totals.sessionsEnded += 1
    if session.fresh then
        self.totals.freshSessionsEnded += 1
    end
end

return PlaytestReport
