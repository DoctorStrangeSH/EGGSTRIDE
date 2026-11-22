local Rules = {}

Rules.PrepareSeconds = 9
Rules.RunSeconds = 25
Rules.Weekly = {
    duration = 35, tier = 2, checkpointRadius = 6, eggStep = 3,
    order = { "First", "Second", "Egg", "Second", "First", "Finish" },
    labels = { "Добеги до метки 1", "Добеги до метки 2", "Забери тренировочное яйцо",
        "Вернись к метке 2", "Вернись к метке 1", "Вернись на финиш" },
}
Rules.CarryMultiplier = 0.75
Rules.StartCoins = 15
Rules.GateX = 28
Rules.Abilities = {
    vine = { name = "Лиана", duration = 6, effect = "Мост на %d сек.", hint = "Используй у ростка" },
    relay = { name = "Грозовой разряд", effect = "Переносит на Янтарный остров", hint = "Используй у маяка" },
    anchor = { name = "Якорь ветра", duration = 6, effect = "Убирает встречный ветер на %d сек.", hint = "Используй у стойки тропы" },
}
Rules.WindTailwind = 1.30
Rules.WindHeadwind = 0.70
Rules.WindSwitch = { duration = 6, partnerRadius = 14 }
Rules.StormTrial = { name = "Грозовой след", secondsLeft = 5 }
Rules.RarePetChance = { ["Обычное"] = 15, ["Редкое"] = 35 }
Rules.Vaults = {
    {
        id = "meadow", name = "Луговой", x = 63, tier = 1, coins = 32,
        pets = {
            common = { id = "leaf_tail", name = "Листохвост", rarity = "Обычный", color = { 176, 220, 111 } },
            rare = { id = "dew_moth", name = "Росокрыл", rarity = "Редкий", color = { 113, 232, 235 } },
        },
        eggs = {
            { id = "leaf_shell", name = "Листовое яйцо", rarity = "Обычное", weight = 80, ability = "vine", color = { 176, 220, 111 } },
            { id = "dew_shell", name = "Яйцо росы", rarity = "Редкое", weight = 20, ability = "vine", color = { 113, 232, 235 } },
        },
    },
    {
        id = "amber", name = "Янтарный", x = 143, tier = 2, coins = 54,
        pets = {
            common = { id = "amber_crab", name = "Янтарный краб", rarity = "Обычный", color = { 255, 178, 76 } },
            rare = { id = "prism_fox", name = "Призмолис", rarity = "Редкий", color = { 255, 113, 165 } },
        },
        eggs = {
            { id = "amber_shell", name = "Янтарное яйцо", rarity = "Обычное", weight = 85, ability = "anchor", color = { 255, 178, 76 } },
            { id = "prism_shell", name = "Призматическое яйцо", rarity = "Редкое", weight = 15, ability = "anchor", color = { 255, 113, 165 } },
        },
    },
    {
        id = "storm", name = "Грозовой", x = 252, tier = 4, coins = 95,
        pets = {
            common = { id = "thunder_puff", name = "Громопух", rarity = "Обычный", color = { 182, 150, 255 } },
            rare = { id = "lightning_kite", name = "Молниехвост", rarity = "Редкий", color = { 255, 237, 108 } },
        },
        eggs = {
            { id = "thunder_shell", name = "Грозовое яйцо", rarity = "Обычное", weight = 90, ability = "relay", color = { 182, 150, 255 } },
            { id = "lightning_shell", name = "Яйцо молнии", rarity = "Редкое", weight = 10, ability = "relay", color = { 255, 237, 108 } },
        },
    },
}
Rules.Speeds = { 16, 20, 24, 30, 36 }
Rules.UpgradeCosts = { 15, 35, 65, 95 }

function Rules.clock(elapsed)
    local offset = elapsed % (Rules.PrepareSeconds + Rules.RunSeconds)
    if offset < Rules.PrepareSeconds then
        return false, math.ceil(Rules.PrepareSeconds - offset)
    end
    return true, math.ceil(Rules.PrepareSeconds + Rules.RunSeconds - offset)
end

function Rules.speed(tier, carrying)
    return Rules.Speeds[tier] * (if carrying then Rules.CarryMultiplier else 1)
end

function Rules.canCollect(tier, vault, carrying, open, delivered)
    return open and not carrying and not delivered and tier >= vault.tier
end

function Rules.eggForRoll(vault, roll)
    for _, egg in ipairs(vault.eggs) do
        roll -= egg.weight
        if roll <= 0 then
            return egg
        end
    end
    error("Egg roll exceeds the biome pool")
end

function Rules.hatchForRoll(vault, egg, roll)
    return if roll <= Rules.RarePetChance[egg.rarity] then vault.pets.rare else vault.pets.common
end

function Rules.improvedDelivery(previous, elapsed, limit)
    if not (elapsed > 0 and elapsed <= (limit or Rules.RunSeconds)) then
        return nil
    end
    local milliseconds = math.max(1, math.round(elapsed * 1000))
    if not previous or milliseconds < previous then
        return milliseconds
    end
    return nil
end

function Rules.weekId(timestamp)
    return math.floor((timestamp - 4 * 86400) / (7 * 86400))
end

function Rules.weeklySplitPlausible(distance, elapsed, carrying)
    local lowerBound = math.max(0, distance - 2 * Rules.Weekly.checkpointRadius)
    local pace = Rules.speed(Rules.Weekly.tier, carrying)
    return elapsed + 0.3 >= lowerBound / (pace * 1.2)
end

function Rules.weeklyBest(record, week)
    return if record and record.week == week then record.time else nil
end

function Rules.deliveryTimeText(milliseconds)
    return (string.format("%.2f", milliseconds / 1000):gsub("%.", ",")) .. " сек."
end

function Rules.stormTrialComplete(egg, usedAbility, secondsLeft)
    return egg ~= nil and egg.ability == "relay" and usedAbility == true
        and secondsLeft >= Rules.StormTrial.secondsLeft
end

function Rules.abilityEffect(ability)
    return if ability.duration then string.format(ability.effect, ability.duration) else ability.effect
end

function Rules.windDirection(cycle)
    return if cycle % 2 == 0 then 1 else -1
end

function Rules.canSwitchWind(direction, used, hasCarrier)
    return direction == 1 and not used and hasCarrier
end

function Rules.windFactor(direction, speedX, protected)
    if direction == 0 or math.abs(speedX) < 1 then
        return 1
    end
    if direction * speedX > 0 then
        return Rules.WindTailwind
    end
    return if protected then 1 else Rules.WindHeadwind
end

function Rules.onboardingAfterPickup(step)
    if step == 1 then
        return 2
    elseif step == 3 then
        return 4
    end
    return step
end

return Rules
