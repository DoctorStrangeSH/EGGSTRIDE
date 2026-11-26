-- Wind gliding between the floating islands.
-- Launch pads throw the player into the air, the glider opens at the top of the
-- jump (or on a second jump in the air), updrafts lift gliders over long gaps.
local Glide = {}

-- Horizontal glide speed: a fixed part plus half of WalkSpeed, so upgrades and
-- cargo still matter but every pad reaches the next island.
Glide.BaseSpeed = 30
Glide.WalkFactor = 0.5
-- Sink rate in studs per second without cargo.
Glide.Sink = 8
-- Updrafts push the glider up at this speed.
Glide.UpdraftRise = 40
-- Cargo makes the glider sink faster.
Glide.CargoSink = 1.3
Glide.StolenSink = 1.3
Glide.LegendarySink = 1.5
Glide.PadCooldown = 1.2

-- Islands sit at x = 76 (Meadow), 180 (Amber) and 360 (Storm), each 40 studs wide.
-- Every pad throws the player toward the next island in its direction.
-- Pad flights are guided: the glider folds itself above the target island centre.
Glide.Pads = {
    { id = "meadow_west", x = 59, z = 22, direction = -1, targetX = 0, label = "К лагерю" },
    { id = "meadow_east", x = 93, z = 22, direction = 1, targetX = 180, label = "К Янтарному" },
    { id = "amber_west", x = 163, z = 22, direction = -1, targetX = 76, label = "К Луговому" },
    { id = "amber_east", x = 197, z = 22, direction = 1, targetX = 360, label = "К Грозовому" },
    { id = "storm_west", x = 343, z = 22, direction = -1, targetX = 180, label = "К Янтарному" },
}
-- Horizontal speed kept after the glider folds, so the player drops onto the island.
Glide.LandingDrift = 6
Glide.PadBoost = { forward = 60, up = 115 }

-- Updraft columns in the long gap between Amber and Storm.
Glide.Updrafts = {
    { x = 270, z = 22, radius = 14, height = 60 },
}

function Glide.horizontalSpeed(walkSpeed)
    return Glide.BaseSpeed + walkSpeed * Glide.WalkFactor
end

-- Multiplier for the sink rate given what the player carries.
function Glide.sinkMultiplier(carryingEgg, carryingStolen, eggStage)
    local multiplier = 1
    if carryingEgg then
        multiplier *= Glide.CargoSink
        if eggStage == 4 then
            multiplier *= Glide.LegendarySink / Glide.CargoSink
        end
    end
    if carryingStolen then
        multiplier *= Glide.StolenSink
    end
    return multiplier
end

-- Vertical speed while gliding: fall no faster than the sink rate, rise in updrafts.
function Glide.verticalSpeed(current, sinkMultiplier, inUpdraft)
    if inUpdraft then
        return math.max(current, Glide.UpdraftRise)
    end
    return math.max(current, -Glide.Sink * sinkMultiplier)
end

function Glide.inUpdraft(updraft, position)
    local dx, dz = position.X - updraft.x, position.Z - updraft.z
    return dx * dx + dz * dz <= updraft.radius * updraft.radius
        and position.Y >= -30 and position.Y <= updraft.height
end

function Glide.passedTarget(pad, x)
    return (x - pad.targetX) * pad.direction >= 0
end

-- Launch velocity for a pad, as a plain table so tests run without Roblox types.
function Glide.padVelocity(pad)
    return { x = pad.direction * Glide.PadBoost.forward, y = Glide.PadBoost.up, z = 0 }
end

return Glide
