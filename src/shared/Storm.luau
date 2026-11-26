-- Sky storm: every few rounds the sky darkens and one golden egg appears high
-- above an island for the whole server. Glide up through its updraft, grab it,
-- and carry it to your base while everyone else tries to intercept you.
local Storm = {}

-- A round lasts PrepareSeconds + RunSeconds (about a minute), so this is roughly every 10 minutes.
Storm.EveryRounds = 10
-- The first storm comes a few minutes after the server starts.
Storm.FirstRound = 4
Storm.EggHeight = 34
Storm.UpdraftRadius = 7
Storm.UpdraftHeight = 40
Storm.PromptDistance = 12
Storm.CarrySpeed = 0.8
Storm.GlideBoost = 1.25
Storm.InterceptHoldSeconds = 1
Storm.InterceptRadius = 8
Storm.Coins = 150
-- The golden egg hatches one of the mythic prize pets.
Storm.Pets = { "forest_wyrm", "mirage_roc", "eclipse_drake" }

-- Where the egg can appear. "updraft" spots reuse the permanent updraft.
Storm.Spots = {
    { id = "meadow", x = 76, z = -14, label = "Луговым островом" },
    { id = "amber", x = 180, z = -10, label = "Янтарным островом" },
    { id = "gap", x = 270, z = 22, label = "пролётом к Грозовому", updraft = true },
    { id = "storm", x = 360, z = -10, label = "Грозовым островом" },
}

function Storm.isStormRound(cycle)
    return cycle >= Storm.FirstRound and (cycle - Storm.FirstRound) % Storm.EveryRounds == 0
end

-- "next" during the round before a storm, "warning" while the storm round prepares,
-- "active" while its gates are open.
function Storm.state(cycle, open)
    if Storm.isStormRound(cycle) then
        return if open then "active" else "warning"
    end
    if open and Storm.isStormRound(cycle + 1) then
        return "next"
    end
    return nil
end

function Storm.spotForRoll(roll)
    return Storm.Spots[(roll - 1) % #Storm.Spots + 1]
end

return Storm
