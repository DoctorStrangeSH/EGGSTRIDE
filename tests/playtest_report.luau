local PlaytestReport = require("../src/server/PlaytestReport")
local Rules = require("../src/shared/Rules")

local report = PlaytestReport.new(Rules.Vaults, false)
local totals = report.totals
report:join("fresh", 1000, true)
report:join("late", 1000, true)
report:join("returning", 1000, false)

report:upgrade("fresh", "amber", 1010)
report:upgrade("returning", "storm", 1020)

report:pickUp("fresh", "meadow", false, 1025)
report:finish("fresh", "timeout")
report:finish("fresh", "fall") -- No cargo remains after the round closes.
report:pickUp("fresh", "meadow", false, 1108)
assert(totals.freshRepeatPickups == 0)
report:finish("fresh", "delivered", 1120, 5, true)

report:pickUp("fresh", "amber", true, 1140)
report:finish("fresh", "delivered", 1160, 2, false)
report:upgrade("fresh", "storm", 1163)
report:pickUp("fresh", "storm", true, 1165)
report:finish("fresh", "fall")

report:pickUp("late", "meadow", false, 1100)
report:finish("late", "delivered", 1120.01, 3, false)
report:pickUp("returning", "amber", false, 1200)
report:finish("returning", "respawn")
report:pickUp("returning", "amber", false, 1220)
report:missPrize("amber")

report:leave("returning")
report:leave("returning")
report:leave("fresh")

assert(totals.windEnabled == false)
assert(totals.sessionsStarted == 3 and totals.sessionsEnded == 2)
assert(totals.freshSessions == 2 and totals.freshSessionsEnded == 1)
assert(totals.freshFirstPickups == 2 and totals.freshFirstDeliveries == 2)
assert(totals.freshDeliveriesWithin120s == 1 and totals.freshRepeatPickups == 1)
assert(totals.freshUpgrades.amber.count == 1 and totals.freshUpgrades.amber.secondsTotal == 10)
assert(totals.freshUpgrades.storm.count == 1 and totals.freshUpgrades.storm.secondsTotal == 163)
assert(next(report.sessions) == "late")

local meadow = totals.biomes.meadow
assert(meadow.pickups == 3 and meadow.delivered == 2 and meadow.timeout == 1 and meadow.fall == 0)
assert(meadow.shortcutDeliveries == 1 and meadow.secondsLeftTotal == 8)
assert(math.abs(meadow.deliverySecondsTotal - 32.01) < 1e-8)
local amber = totals.biomes.amber
assert(amber.pickups == 3 and amber.delivered == 1 and amber.respawn == 1 and amber.left == 1)
assert(amber.prizePickups == 1 and amber.prizeDelivered == 1 and amber.prizeClaimMisses == 1)
local storm = totals.biomes.storm
assert(storm.prizePickups == 1 and storm.prizeDelivered == 0 and storm.fall == 1)

print("Eggstride playtest report: OK")
