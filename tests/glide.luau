local Glide = require("../src/shared/Glide")
local Locale = require("../src/shared/Locale")
local Rules = require("../src/shared/Rules")

local gravity = 196.2

-- Worst case: slowest speed, carrying a legendary egg. Distance covered from a pad
-- before dropping back to island height must reach the next island edge.
local function reach(walkSpeed, sinkMultiplier, startX, direction, updrafts)
    local dt = 1 / 60
    local x, y, vy = startX, 0, Glide.PadBoost.up
    local speed = Glide.horizontalSpeed(walkSpeed)
    for _ = 1, 60 * 30 do
        vy -= gravity * dt
        local inUpdraft = false
        for _, updraft in ipairs(updrafts) do
            -- Gliders aim through the column on the pad lane.
            if Glide.inUpdraft(updraft, { X = x, Y = y, Z = updraft.z }) then
                inUpdraft = true
            end
        end
        vy = Glide.verticalSpeed(vy, sinkMultiplier, inUpdraft)
        x += direction * speed * dt
        y += vy * dt
        if y < 0 and vy < 0 then
            return x
        end
    end
    return x
end

local slowest = Rules.Speeds[1] * Rules.CarryMultiplier
local heaviest = Glide.sinkMultiplier(true, false, 4)
local islandHalf = 20
local function edges(vault)
    return vault.x - islandHalf, vault.x + islandHalf
end
local meadowWest, meadowEast = edges(Rules.Vaults[1])
local amberWest, amberEast = edges(Rules.Vaults[2])
local stormWest = edges(Rules.Vaults[3])
local campEast = 25

-- Guided flights must still be in the air when they pass the target island centre,
-- even for the slowest, heaviest glider, and the target must lie on an island.
local islands = { { -25, campEast }, { meadowWest, meadowEast }, { amberWest, amberEast }, { stormWest, stormWest + 40 } }
for _, pad in ipairs(Glide.Pads) do
    local landed = reach(slowest, heaviest, pad.x, pad.direction, Glide.Updrafts)
    assert(Glide.passedTarget(pad, landed), ("Pad %s falls short at x=%.1f"):format(pad.id, landed))
    local onIsland = false
    for _, island in ipairs(islands) do
        onIsland = onIsland or (pad.targetX >= island[1] + 5 and pad.targetX <= island[2] - 5)
    end
    assert(onIsland, "Pad target is not over an island: " .. pad.id)
    assert(Locale.text("en", "Трамплин · " .. pad.label) ~= "Трамплин · " .. pad.label, "Missing English for pad " .. pad.id)
end
assert(meadowWest < Glide.Pads[1].x)

-- Sink rules
assert(Glide.sinkMultiplier(false, false, nil) == 1)
assert(math.abs(Glide.sinkMultiplier(true, false, 2) - Glide.CargoSink) < 1e-9)
assert(math.abs(Glide.sinkMultiplier(true, false, 4) - Glide.LegendarySink) < 1e-9)
assert(Glide.verticalSpeed(-50, 1, false) == -Glide.Sink)
assert(Glide.verticalSpeed(10, 1, false) == 10)
assert(Glide.verticalSpeed(-50, 1, true) == Glide.UpdraftRise)

print("Eggstride glide: OK")
