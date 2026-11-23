local Rules = {}
Rules.Trails = {
    { id = "mint", name = "Мятный ветер", first = { 114, 255, 201 }, last = { 112, 189, 255 }, lifetime = 0.33 },
    { id = "ember", name = "Янтарная искра", first = { 255, 222, 111 }, last = { 255, 114, 115 }, lifetime = 0.36 },
    { id = "aurora", name = "Полярное сияние", first = { 198, 155, 255 }, last = { 109, 247, 230 }, lifetime = 0.40 },
}

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
Rules.Abilities = {
    vine = { name = "Лиана", duration = 11, hint = "Через зелёный росток" },
    relay = { name = "Разряд", hint = "Через фиолетовый маяк" },
    anchor = { name = "Якорь", hint = "Через синюю тропу" },
}
Rules.WindTailwind = 1.30
Rules.WindHeadwind = 0.70
Rules.WindSwitch = { duration = 6, partnerRadius = 14 }
Rules.StormTrial = { name = "Грозовой след", secondsLeft = 5 }
local function species(id, name, rarity, red, green, blue, form)
    return { id = id, name = name, rarity = rarity, color = { red, green, blue }, form = form }
end

Rules.Vaults = {
    {
        id = "meadow", material = "Луговой нектар", name = "Луговой", x = 76, tier = 1, coins = 32,
        pets = {
            { id = "leaf_tail", name = "Листохвост", rarity = "Обычный", color = { 176, 220, 111 } },
            { id = "dew_moth", name = "Росокрыл", rarity = "Редкий", color = { 113, 232, 235 } },
            species("clover_hare", "Клеверный заяц", "Обычный", 164, 223, 130, "ears"),
            species("honey_bee", "Медовая пчёлка", "Обычный", 229, 198, 105, "wings"),
            species("reed_frog", "Камышовая квакша", "Обычный", 249, 151, 185, "horns"),
            species("moss_tortoise", "Моховая черепашка", "Обычный", 124, 224, 192, "fins"),
            species("acorn_mouse", "Желудевая мышка", "Обычный", 162, 198, 251, "tail"),
            species("berry_snail", "Ягодная улитка", "Обычный", 191, 158, 235, "shell"),
            species("pollen_lark", "Пыльцевой жаворонок", "Редкий", 244, 190, 139, "crest"),
            species("birch_owl", "Берёзовая сова", "Редкий", 105, 199, 157, "frill"),
            species("fern_fox", "Папоротниковая лиса", "Редкий", 232, 115, 128, "spring"),
            species("moon_cricket", "Лунный сверчок", "Редкий", 224, 239, 137, "ribbon"),
        },
    },
    {
        id = "amber", material = "Янтарная крошка", name = "Янтарный", x = 180, tier = 2, coins = 54,
        pets = {
            { id = "amber_crab", name = "Янтарный краб", rarity = "Обычный", color = { 255, 178, 76 } },
            { id = "prism_fox", name = "Призмолис", rarity = "Редкий", color = { 255, 113, 165 } },
            species("sand_jerboa", "Песчаный тушканчик", "Обычный", 255, 199, 122, "ears"),
            species("dune_tortoise", "Дюнная черепашка", "Обычный", 219, 132, 73, "wings"),
            species("copper_beetle", "Медный жук", "Обычный", 250, 151, 79, "horns"),
            species("saffron_gecko", "Шафрановый геккон", "Обычный", 231, 105, 124, "fins"),
            species("flint_hare", "Кремнёвый заяц", "Обычный", 225, 165, 228, "tail"),
            species("pebble_pangolin", "Галечный панголин", "Обычный", 171, 137, 98, "shell"),
            species("opal_moth", "Опаловый мотылёк", "Редкий", 248, 223, 129, "crest"),
            species("citrine_bat", "Цитриновая мышь", "Редкий", 179, 211, 189, "frill"),
            species("sun_kestrel", "Солнечная пустельга", "Редкий", 235, 152, 122, "spring"),
            species("glass_serpent", "Стеклянная змейка", "Редкий", 152, 124, 187, "ribbon"),
        },
    },
    {
        id = "storm", material = "Грозовая пыль", name = "Грозовой", x = 360, tier = 3, coins = 95,
        pets = {
            { id = "thunder_puff", name = "Громопух", rarity = "Обычный", color = { 182, 150, 255 } },
            { id = "lightning_kite", name = "Молниехвост", rarity = "Редкий", color = { 255, 237, 108 } },
            species("mist_mouse", "Туманная мышка", "Обычный", 172, 182, 252, "ears"),
            species("frost_bun", "Инейный кролик", "Обычный", 118, 210, 245, "wings"),
            species("sleet_frog", "Снежная квакша", "Обычный", 203, 173, 255, "horns"),
            species("cloud_raven", "Облачный ворон", "Обычный", 117, 149, 228, "fins"),
            species("ice_tortoise", "Ледяная черепашка", "Обычный", 174, 228, 237, "tail"),
            species("gust_otter", "Вихревая выдра", "Обычный", 145, 109, 211, "shell"),
            species("squall_gecko", "Шквальный геккон", "Редкий", 138, 190, 251, "crest"),
            species("static_moth", "Искристый мотылёк", "Редкий", 226, 159, 237, "frill"),
            species("north_owl", "Северная сова", "Редкий", 186, 225, 161, "spring"),
            species("echo_bat", "Эховая мышь", "Редкий", 124, 242, 222, "ribbon"),
        },
    },
}
Rules.Prizes = {
    { id = "meadow", name = "Луговое призовое яйцо", location = "Луговом", vaultIndex = 1, bonus = 20, pets = {
        species("orchid_deer", "Орхидейный олень", "Редкий", 162, 198, 251, "tail"),
        species("dew_hummingbird", "Колибри росы", "Эпический", 191, 158, 235, "shell"),
        species("amber_bumble", "Золотой шмель", "Эпический", 244, 190, 139, "crest"),
        species("spring_griffin", "Весенний грифон", "Легендарный", 105, 199, 157, "frill"),
        species("forest_wyrm", "Дракон чащи", "Мифический", 232, 115, 128, "spring"),
    } },
    { id = "amber", name = "Янтарное призовое яйцо", location = "Янтарном", vaultIndex = 2, bonus = 35, pets = {
        species("coral_scorpion", "Коралловый скорпион", "Редкий", 225, 165, 228, "tail"),
        species("topaz_cat", "Топазовый кот", "Эпический", 171, 137, 98, "shell"),
        species("desert_sphinx", "Дюнный сфинкс", "Эпический", 248, 223, 129, "crest"),
        species("sun_dragon", "Дракон полудня", "Легендарный", 179, 211, 189, "frill"),
        species("mirage_roc", "Птица миража", "Мифический", 235, 152, 122, "spring"),
    } },
    { id = "storm", name = "Грозовая реликвия", location = "Грозовом", vaultIndex = 3, bonus = 60, pets = {
        { id = "aurora_falcon", name = "Сияющий сокол", rarity = "Эпический", color = { 127, 255, 209 }, form = "wings" },
        { id = "storm_wyvern", name = "Грозовая виверна", rarity = "Эпический", color = { 231, 118, 243 }, form = "horns" },
        { id = "comet_otter", name = "Кометная выдра", rarity = "Эпический", color = { 120, 206, 255 }, form = "tail" },
        { id = "dawn_phoenix", name = "Рассветный феникс", rarity = "Легендарный", color = { 255, 196, 86 }, form = "wings" },
        { id = "eclipse_drake", name = "Дракон затмения", rarity = "Мифический", color = { 157, 116, 242 }, form = "horns" },
    } },
}

Rules.Offspring = {
    {
        species("bloom_moth", "Цветокрыл", "Редкий", 158, 237, 125, "wings"),
        species("nectar_hopper", "Нектарный прыгун", "Эпический", 105, 199, 157, "frill"),
        species("crown_frog", "Цветочная квакша", "Редкий", 232, 115, 128, "spring"),
        species("silver_clover", "Сереброклевер", "Эпический", 224, 239, 137, "ribbon"),
        species("hazel_drake", "Ореховый дракончик", "Редкий", 171, 233, 200, "ears"),
        species("tulip_tortoise", "Тюльпановая черепашка", "Эпический", 224, 181, 241, "wings"),
        species("mist_bloom", "Туманоцвет", "Редкий", 164, 223, 130, "horns"),
        species("leaf_glider", "Листопланёр", "Эпический", 229, 198, 105, "fins"),
        species("pearl_slug", "Жемчужный слизень", "Редкий", 249, 151, 185, "tail"),
        species("raspberry_wren", "Малиновый крапивник", "Эпический", 124, 224, 192, "shell"),
        species("fern_stag", "Папоротниковый олень", "Редкий", 162, 198, 251, "crest"),
        species("honey_marten", "Медовая куница", "Эпический", 191, 158, 235, "ears"),
        species("birch_kirin", "Берёзовый кирин", "Редкий", 244, 190, 139, "wings"),
        species("wood_moth", "Лесной шелкопряд", "Эпический", 105, 199, 157, "horns"),
        species("petal_ray", "Лепестковый скат", "Редкий", 232, 115, 128, "fins"),
        species("clover_cub", "Клеверный медвежонок", "Эпический", 224, 239, 137, "tail"),
    },
    {
        species("sun_shell", "Солнечный панцирник", "Редкий", 244, 166, 75, "fins"),
        species("fire_gazelle", "Огненная газель", "Эпический", 179, 211, 189, "frill"),
        species("opal_drake", "Опаловый дракончик", "Редкий", 235, 152, 122, "spring"),
        species("sand_sailor", "Песчаный парусник", "Эпический", 152, 124, 187, "ribbon"),
        species("gold_sparrow", "Золотой воробей", "Редкий", 255, 215, 168, "ears"),
        species("copper_fox", "Медная лиса", "Эпический", 247, 125, 167, "wings"),
        species("silica_skink", "Кварцевый сцинк", "Редкий", 255, 199, 122, "horns"),
        species("ruby_crab", "Рубиновый краб", "Эпический", 219, 132, 73, "fins"),
        species("glow_jackal", "Сияющий шакал", "Редкий", 250, 151, 79, "tail"),
        species("resin_moth", "Смоляной мотылёк", "Эпический", 231, 105, 124, "shell"),
        species("prism_beetle", "Призматический жук", "Редкий", 225, 165, 228, "crest"),
        species("dune_serval", "Дюнный сервал", "Эпический", 171, 137, 98, "ears"),
        species("citrine_ram", "Цитриновый баран", "Редкий", 248, 223, 129, "wings"),
        species("sunset_gecko", "Закатный геккон", "Эпический", 179, 211, 189, "horns"),
        species("stone_kite", "Каменный коршун", "Редкий", 235, 152, 122, "fins"),
        species("ember_lynx", "Угольная рысь", "Эпический", 152, 124, 187, "tail"),
    },
    {
        species("thunder_lynx", "Громорысь", "Эпический", 141, 131, 251, "horns"),
        species("aurora_moth", "Мотылёк сияния", "Эпический", 226, 159, 237, "frill"),
        species("frost_ferret", "Морозный хорёк", "Редкий", 186, 225, 161, "spring"),
        species("thunder_tortoise", "Громовая черепаха", "Эпический", 124, 242, 222, "ribbon"),
        species("storm_hare", "Грозовой заяц", "Редкий", 150, 159, 221, "ears"),
        species("snow_marten", "Снежная куница", "Эпический", 226, 209, 250, "wings"),
        species("sky_serpent", "Небесная змейка", "Редкий", 172, 182, 252, "horns"),
        species("ice_tern", "Ледяная крачка", "Эпический", 118, 210, 245, "fins"),
        species("violet_owl", "Фиалковая сова", "Редкий", 203, 173, 255, "tail"),
        species("whirl_beetle", "Вихревой жук", "Эпический", 117, 149, 228, "shell"),
        species("cloud_seal", "Облачный тюлень", "Редкий", 174, 228, 237, "crest"),
        species("tundra_griffin", "Тундровый грифон", "Эпический", 145, 109, 211, "ears"),
        { id = "cloud_lynx", name = "Облачная рысь", rarity = "Редкий", color = { 139, 218, 255 }, form = "ears" },
        { id = "rain_heron", name = "Дождевая цапля", rarity = "Редкий", color = { 95, 158, 249 }, form = "wings" },
        { id = "hail_ram", name = "Градовый баран", rarity = "Редкий", color = { 211, 235, 255 }, form = "horns" },
        { id = "violet_ray", name = "Сиреневый скат", rarity = "Редкий", color = { 193, 150, 255 }, form = "fins" },
        { id = "spark_marten", name = "Искровая куница", rarity = "Редкий", color = { 255, 154, 86 }, form = "tail" },
    },
}

Rules.Mutations = {
    {
        vault = Rules.Vaults[1], parent = Rules.Offspring[1][1], cost = 2,
        route = "Вернись с луговым яйцом по мосту из лиан",
        appearance = "Розовые крылья и светящаяся метка",
        pet = species("bloom_moth_petal", "Лепестковый Цветокрыл", "Редкий", 242, 156, 196, "wings"),
    },
    {
        vault = Rules.Vaults[2], parent = Rules.Offspring[2][1], cost = 2,
        route = "Вернись с янтарным яйцом по синей ветровой тропе",
        appearance = "Золотой панцирь и светящаяся метка",
        pet = species("sun_shell_topaz", "Топазовый панцирник", "Редкий", 255, 186, 85, "shell"),
    },
    {
        vault = Rules.Vaults[3], parent = Rules.Offspring[3][1], cost = 2,
        route = "Вернись с грозовым яйцом через фиолетовый маяк",
        appearance = "Бирюзовые рога и светящаяся метка",
        pet = species("thunder_lynx_aurora", "Сияющая Громорысь", "Эпический", 122, 236, 245, "horns"),
    },
}
for _, mutation in ipairs(Rules.Mutations) do
    mutation.pet.mutated = true
end

Rules.SeasonPets = {
    species("season_sky_firefly", "Небесный светляк", "Эпический", 133, 219, 255, "wings"),
    species("season_sunset_firefly", "Закатный светляк", "Эпический", 255, 155, 120, "wings"),
    species("season_lunar_firefly", "Лунный светляк", "Легендарный", 194, 177, 255, "wings"),
    species("season_polar_firefly", "Полярный светляк", "Легендарный", 146, 255, 218, "wings"),
}
Rules.Season = {
    id = "sky_routes_01",
    name = "Тропы неба",
    quests = {
        { id = "delivery", label = "Доставь яйца в любых биомах", goal = 3, xp = 30 },
        { id = "route", label = "Доставь яйца по особым маршрутам", goal = 2, xp = 40 },
        { id = "record", label = "Улучши время доставки недели в одном биоме", goal = 1, xp = 40 },
        { id = "weekly", label = "Финишируй с зачётом в забеге недели", goal = 1, xp = 50 },
    },
    rewards = {
        { xp = 30, coins = 40, label = "40 монет" },
        { xp = 70, material = "meadow", amount = 2, label = "2 луговых нектара" },
        { xp = 120, coins = 100, label = "100 монет" },
        { xp = 220, material = "amber", amount = 3, label = "3 янтарных крошки" },
        { xp = 360, label = Rules.SeasonPets[1].name, pet = Rules.SeasonPets[1] },
    },
    premiumRewards = {
        { xp = 70, label = Rules.SeasonPets[2].name, pet = Rules.SeasonPets[2] },
        { xp = 220, label = Rules.SeasonPets[3].name, pet = Rules.SeasonPets[3] },
        { xp = 360, label = Rules.SeasonPets[4].name, pet = Rules.SeasonPets[4] },
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

function Rules.returnBridgeStage(stage, relativeX)
    if stage == 0 and relativeX >= 0.25 then
        return 1
    elseif stage == 1 and relativeX <= -0.25 then
        return 2
    end
    return stage
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
