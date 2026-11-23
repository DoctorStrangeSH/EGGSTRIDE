local Rules = {}

Rules.PrepareSeconds = 7
Rules.RunSeconds = 55
Rules.Weekly = {
    rewardCoins = 75, rewardTime = 20000,
    countdown = 3, duration = 35, tier = 2, checkpointRadius = 6, eggStep = 3,
    order = { "First", "Second", "Egg", "Second", "First", "Finish" },
    labels = { "Добеги до метки 1", "Добеги до метки 2", "Забери тренировочное яйцо",
        "Вернись к метке 2", "Вернись к метке 1", "Вернись на финиш" },
}
Rules.CarryMultiplier = 0.75
Rules.StartCoins = 15
Rules.GateX = 29
Rules.HatchX = 14
Rules.Prizes = {
    { id = "amber", name = "Янтарное призовое яйцо", vaultIndex = 2, bonus = 35 },
    { id = "storm", name = "Грозовая реликвия", vaultIndex = 3, bonus = 60 },
}
Rules.RelicPets = {
    { id = "cloud_lynx", name = "Облачная рысь", rarity = "Редкий", color = { 139, 218, 255 }, form = "ears" },
    { id = "rain_heron", name = "Дождевая цапля", rarity = "Редкий", color = { 95, 158, 249 }, form = "wings" },
    { id = "hail_ram", name = "Градовый баран", rarity = "Редкий", color = { 211, 235, 255 }, form = "horns" },
    { id = "violet_ray", name = "Сиреневый скат", rarity = "Редкий", color = { 193, 150, 255 }, form = "fins" },
    { id = "spark_marten", name = "Искровая куница", rarity = "Редкий", color = { 255, 154, 86 }, form = "tail" },
    { id = "aurora_falcon", name = "Сияющий сокол", rarity = "Эпический", color = { 127, 255, 209 }, form = "wings" },
    { id = "storm_wyvern", name = "Грозовая виверна", rarity = "Эпический", color = { 231, 118, 243 }, form = "horns" },
    { id = "comet_otter", name = "Кометная выдра", rarity = "Эпический", color = { 120, 206, 255 }, form = "tail" },
    { id = "dawn_phoenix", name = "Рассветный феникс", rarity = "Легендарный", color = { 255, 196, 86 }, form = "wings" },
    { id = "eclipse_drake", name = "Дракон затмения", rarity = "Мифический", color = { 157, 116, 242 }, form = "horns" },
}
Rules.Abilities = {
    vine = { name = "Лиана", duration = 11, hint = "Через зелёный росток" },
    relay = { name = "Разряд", hint = "Через фиолетовый маяк" },
    anchor = { name = "Якорь", hint = "Через синюю тропу" },
}
Rules.WindTailwind = 1.30
Rules.WindHeadwind = 0.70
Rules.WindSwitch = { duration = 6, partnerRadius = 14 }
Rules.StormTrial = { name = "Грозовой след", secondsLeft = 5 }
Rules.Vaults = {
    {
        id = "meadow", name = "Луговой", x = 76, tier = 1, coins = 32,
        pets = {
            common = { id = "leaf_tail", name = "Листохвост", rarity = "Обычный", color = { 176, 220, 111 } },
            rare = { id = "dew_moth", name = "Росокрыл", rarity = "Редкий", color = { 113, 232, 235 } },
        },
    },
    {
        id = "amber", name = "Янтарный", x = 180, tier = 2, coins = 54,
        pets = {
            common = { id = "amber_crab", name = "Янтарный краб", rarity = "Обычный", color = { 255, 178, 76 } },
            rare = { id = "prism_fox", name = "Призмолис", rarity = "Редкий", color = { 255, 113, 165 } },
        },
    },
    {
        id = "storm", name = "Грозовой", x = 360, tier = 3, coins = 95,
        pets = {
            common = { id = "thunder_puff", name = "Громопух", rarity = "Обычный", color = { 182, 150, 255 } },
            rare = { id = "lightning_kite", name = "Молниехвост", rarity = "Редкий", color = { 255, 237, 108 } },
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

function Rules.canUseVault(tier, vault)
    return tier >= vault.tier
end

function Rules.canCollect(carrying, open, delivered)
    return open and not carrying and not delivered
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

function Rules.claimWeeklyReward(entry, week, milliseconds, rankable)
    if not rankable or not (milliseconds >= 1 and milliseconds <= Rules.Weekly.rewardTime)
        or (entry.weeklyRewardWeek and entry.weeklyRewardWeek >= week) then
        return nil
    end

    entry.weeklyRewardWeek = week
    entry.coins += Rules.Weekly.rewardCoins
    return Rules.Weekly.rewardCoins
end

function Rules.weeklyBest(record, week)
    return if record and record.week == week then record.time else nil
end

function Rules.deliveryTimeText(milliseconds)
    return (string.format("%.2f", milliseconds / 1000):gsub("%.", ",")) .. " сек."
end

function Rules.weeklySplitText(milliseconds, reference)
    local time = Rules.deliveryTimeText(milliseconds)
    if not reference then
        return "От старта · " .. time
    end

    local delta = math.round((milliseconds - reference) / 10) * 10
    if delta == 0 then
        return time .. " · Вровень с рекордом"
    end
    local gap = Rules.deliveryTimeText(math.abs(delta))
    return time .. " · " .. gap .. (if delta < 0 then " быстрее" else " медленнее")
end

function Rules.stormTrialComplete(egg, usedAbility, secondsLeft)
    return egg ~= nil and egg.ability == "relay" and usedAbility == true
        and secondsLeft >= Rules.StormTrial.secondsLeft
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
