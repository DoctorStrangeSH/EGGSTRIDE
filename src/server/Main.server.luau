local MarketplaceService = game:GetService("MarketplaceService")
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Eggstride")
local Rules = require(Shared.Rules)
-- Profile.read validates base slots against these limits.
Rules.Bases = require(Shared.Bases)
local Locale = require(Shared.Locale)
local World = require(script.Parent.World)
local Loot = require(script.Parent.Loot)
local Season = require(script.Parent.Season)
local CosmeticShop = require(script.Parent.CosmeticShop)
local Nursery = require(script.Parent.Nursery)
local RoundPrize = require(script.Parent.RoundPrize)
local Profile = require(script.Parent.Profile)
local ProfileStore = require(script.Parent.ProfileStore)
local WeeklyLeaderboard = require(script.Parent.WeeklyLeaderboard)
local PlaytestReport = require(script.Parent.PlaytestReport)
local BaseService = require(script.Parent.BaseService)

local inStudio = RunService:IsStudio()
local studioLanguage = inStudio and workspace:GetAttribute("StudioLanguage")
local windEnabled = workspace:GetAttribute("WindTrailEnabled") ~= false
local playtest
if inStudio and workspace:GetAttribute("PlaytestReportEnabled") == true then
    playtest = PlaytestReport.new(Rules.Vaults, windEnabled)
    local report = Instance.new("BindableFunction")
    report.Name = "EggstridePlaytestReport"
    report.OnInvoke = function()
        return HttpService:JSONEncode(playtest.totals)
    end
    report.Parent = ServerStorage
end
local function languageFor(player)
    return Locale.language(if type(studioLanguage) == "string" then studioLanguage else player.LocaleId)
end

local function translate(player, source, ...)
    return Locale.text(languageFor(player), source, ...)
end
local petCatalog = {}
for _, vault in ipairs(Rules.Vaults) do
    for _, pet in ipairs(vault.pets) do
        petCatalog[pet.id] = pet
    end
end

for _, prize in ipairs(Rules.Prizes) do
    for _, pet in ipairs(prize.pets) do
        petCatalog[pet.id] = pet
    end
end

local recipesByPair, recipesByOffspring = Nursery.recipes(Rules)
for offspringId, recipe in pairs(recipesByOffspring) do
    petCatalog[offspringId] = recipe.offspring
end

local mutationsByPet = {}
for _, mutation in ipairs(Rules.Mutations) do
    petCatalog[mutation.pet.id] = mutation.pet
    mutationsByPet[mutation.pet.id] = mutation
end

for _, pet in ipairs(Rules.SeasonPets) do
    petCatalog[pet.id] = pet
end

local weeklyGroup = "EggstrideWeeklyRunners"
if not workspace:IsCollisionGroupRegistered(weeklyGroup) then
    workspace:RegisterCollisionGroup(weeklyGroup)
end
workspace:CollisionGroupSetCollidable(weeklyGroup, weeklyGroup, false)

local map = World.build(Rules)
local startedAt = workspace:GetServerTimeNow()
local closing = false
local entries = {}
local bases
local round = Instance.new("Folder")
round.Name = "Round"
round:SetAttribute("StartedAt", startedAt)
local targets = {
    Gate = map.gate, FirstEgg = map.vaults[1].part, Hatch = map.hatch, Training = map.shop.Parent,
    Vine = map.sprout, VineExit = map.vineExit, VineBypass = map.vineBypass, Relay = map.stormRelay.origin,
    WindEntrance = map.windTrail.amberMarker, WindExit = map.windTrail.meadowMarker,
}
for name, point in pairs(map.weekly.points) do
    targets["Weekly" .. name] = point
end
for name, part in pairs(targets) do
    local marker = Instance.new("ObjectValue")
    marker.Name = name
    marker.Value = part
    marker.Parent = round
end
local weeklyLeaderboard = WeeklyLeaderboard.new(round, Rules, Locale)
round.Parent = Shared

local equipPet = Instance.new("RemoteEvent")
equipPet.Name = "EquipPet"
equipPet.Parent = Shared

local breedPet = Instance.new("RemoteEvent")
breedPet.Name = "BreedPet"
breedPet.Parent = Shared

local mutatePet = Instance.new("RemoteEvent")
mutatePet.Name = "MutatePet"
mutatePet.Parent = Shared

local claimSeason = Instance.new("RemoteEvent")
claimSeason.Name = "ClaimSeasonReward"
claimSeason.Parent = Shared

local seasonPass = Instance.new("RemoteEvent")
seasonPass.Name = "SeasonPass"
seasonPass.Parent = Shared

local runFeedback = Instance.new("RemoteEvent")
runFeedback.Name = "RunFeedback"
runFeedback.Parent = Shared

local cancelWeekly = Instance.new("RemoteEvent")
cancelWeekly.Name = "CancelWeekly"
cancelWeekly.Parent = Shared

local updatePreference = Instance.new("RemoteEvent")
updatePreference.Name = "UpdatePreference"
updatePreference.Parent = Shared
local preferences = {
    MuteRunSounds = "muteRunSounds",
    ReduceCardMotion = "reduceCardMotion",
}

local loading = {}
local pending = 0
local prizes = {}

local function showPrize(definition, available, source, argument, translateArgument)
    World.showPrize(map.prizes[definition.id], available)
    for _, language in ipairs({ "ru", "en" }) do
        local status = if argument == nil then source else Locale.text(language, source,
            if translateArgument then Locale.text(language, argument) else argument)
        round:SetAttribute("PrizeStatus_" .. definition.id .. "_" .. language, status)
    end
end

local function releasePrize(player, entry)
    local definition = entry.prize
    if definition and RoundPrize.release(prizes[definition.id], player) then
        showPrize(definition, true, "%s снова на пьедестале", definition.name, true)
    end
    entry.prize = nil
end
local previewSeasonPass = inStudio and workspace:GetAttribute("UseStudioDataStore") ~= true
local configuredPassId = workspace:GetAttribute("SeasonPassId")
local seasonPassId = if type(configuredPassId) == "number" and configuredPassId > 0
    and configuredPassId <= 9e15 and configuredPassId % 1 == 0 then configuredPassId else nil

local function setPremiumStatus(player, entry, status)
    entry.premiumStatus = status
    entry.seasonPremium = status == "owned" or status == "previewOwned"
    player:SetAttribute("SeasonPremiumStatus", status)
end

local function refreshPremium(player, entry)
    setPremiumStatus(player, entry, "checking")
    local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, seasonPassId)
    if entries[player] == entry and not closing and entry.premiumStatus == "checking" then
        setPremiumStatus(player, entry, if not ok then "error" elseif owns then "owned" else "locked")
    end
end

local function initPremium(player, entry)
    if previewSeasonPass then
        setPremiumStatus(player, entry, "preview")
    elseif inStudio or not seasonPassId then
        setPremiumStatus(player, entry, "unavailable")
    else
        task.spawn(refreshPremium, player, entry)
    end
end

local logAnalytics = not inStudio
local onboardingSteps = {
    "Joined with profile",
    "Picked up first egg",
    "Hatched first pet",
    "Picked up another egg",
}

local function advanceOnboarding(player, entry, step)
    if step <= entry.onboarding then
        return
    end
    entry.onboarding = step
    if logAnalytics then
        local ok, err = pcall(function()
            AnalyticsService:LogOnboardingFunnelStepEvent(player, step, onboardingSteps[step])
        end)
        if not ok then
            warn("EGGSTRIDE: onboarding analytics failed", step, err)
        end
    end
end

local function leave(player)
    local entry = entries[player]
    if not entry then
        local load = loading[player]
        if load then
            load.cancelled = true
        end
        return
    end
    entries[player] = nil
    if playtest then
        playtest:leave(player)
    end
    releasePrize(player, entry)
    bases.leave(player, entry)
    pending += 1
    local ok, reason = ProfileStore.save(entry.session, Profile.snapshot(entry), true)
    pending -= 1
    if not ok then
        warn("EGGSTRIDE: final save failed", player.UserId, reason)
    end
end

local function characterParts(player)
    local character = player.Character
    if not character then
        return nil, nil
    end
    return character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
end

local function applySpeed(player, entry)
    local humanoid = characterParts(player)
    if humanoid then
        if entry.weekly then
            humanoid.WalkSpeed = Rules.speed(Rules.Weekly.tier, entry.weekly.cargo ~= nil)
        else
            humanoid.WalkSpeed = Rules.speed(entry.tier, entry.egg ~= nil or entry.stolen ~= nil) * (entry.windFactor or 1)
        end
    end
end

local function publish(player, entry, message, ...)
    player:SetAttribute("OnboardingStep", entry.onboarding)
    player:SetAttribute("StormTrailUnlocked", entry.stormTrailUnlocked)
    player:SetAttribute("Coins", entry.coins)
    player:SetAttribute("SpeedTier", entry.tier)
    player:SetAttribute("EquippedPetId", entry.pet and entry.pet.id or "")
    player:SetAttribute("EquippedPet", entry.pet and (entry.pet.name .. " · " .. entry.pet.rarity) or "")
    player:SetAttribute("CarryingEgg", entry.egg ~= nil)
    player:SetAttribute("EggAbility", entry.egg and not entry.abilityUsed and entry.egg.ability or "")
    player:SetAttribute("Delivered", entry.delivered)
    if message then
        player:SetAttribute("NoticeUntil", workspace:GetServerTimeNow() + 5)
        player:SetAttribute("Notice", translate(player, message, ...))
    end
end

local function publishRecipe(player, offspringId, parents)
    local pair = translate(player, parents[1].name) .. " + " .. translate(player, parents[2].name)
    player:SetAttribute("Recipe_" .. offspringId, pair)
end

local function publishSeason(player, entry)
    local progress = entry.season
    player:SetAttribute("SeasonXP", progress.xp)
    for _, quest in ipairs(Rules.Season.quests) do
        player:SetAttribute("SeasonQuest_" .. quest.id, progress.counts[quest.id] or 0)
    end
    for _, vault in ipairs(Rules.Vaults) do
        player:SetAttribute("SeasonDeliveryBest_" .. vault.id, progress.deliveryBests[vault.id])
    end
    for index in ipairs(Rules.Season.rewards) do
        player:SetAttribute("SeasonClaimed_" .. index, progress.claimed[tostring(index)] == true)
    end
    for index in ipairs(Rules.Season.premiumRewards) do
        player:SetAttribute("SeasonPremiumClaimed_" .. index, progress.claimed["premium_" .. index] == true)
    end
end

local function publishBiomeProgress(player, entry, vaultId)
    player:SetAttribute("Deliveries_" .. vaultId, entry.deliveries[vaultId] or 0)
    player:SetAttribute("Material_" .. vaultId, entry.materials[vaultId] or 0)
    player:SetAttribute("Catalyst_" .. vaultId, entry.catalysts[vaultId] or 0)
end

local function accessory(root, name, color, size, offset)
    local visual = Instance.new("Part")
    visual.Name = name
    visual.Shape = Enum.PartType.Ball
    visual.Size = size
    visual.Color = color
    visual.Material = Enum.Material.SmoothPlastic
    visual.CanCollide = false
    visual.CanTouch = false
    visual.CanQuery = false
    visual.Massless = true
    visual.CFrame = root.CFrame * CFrame.new(offset)
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = visual
    weld.Parent = visual
    visual.Parent = root
    return visual
end

local function showPet(root, pet, stormTrailUnlocked)
    local previous = root:FindFirstChild("EggstridePet")
    if previous then
        previous:Destroy()
    end
    local accent = World.variantColor(pet)
    local bodySize = if pet.form == "shell" then Vector3.new(2.04, 1.22, 1.86)
        elseif pet.form == "fins" then Vector3.new(2.02, 1.08, 1.84)
        elseif pet.form == "crest" then Vector3.new(1.66, 1.58, 1.46)
        else Vector3.new(1.9, 1.45, 1.7)
    local body = accessory(root, "EggstridePet", accent, bodySize, Vector3.new(2.6, 0, 2.4))
    for _, x in ipairs({ -0.43, 0.43 }) do
        accessory(body, "Eye", Color3.fromRGB(46, 40, 61), Vector3.new(0.21, 0.27, 0.21), Vector3.new(x, 0.1, -0.72))
        if pet.form == "wings" or pet.form == "fins" then
            local size = if pet.form == "wings" then Vector3.new(1.5, 0.35, 0.78) else Vector3.new(1.15, 0.23, 1.2)
            accessory(body, "Wing", accent, size, Vector3.new(x * 3.05, 0.18, 0.28))
        elseif pet.form == "horns" then
            accessory(body, "Horn", accent:Lerp(Color3.new(1, 1, 1), 0.55),
                Vector3.new(0.24, 0.97, 0.3), Vector3.new(x * 1.35, 0.78, -0.16))
        elseif pet.form == "frill" or pet.form == "ribbon" then
            accessory(body, "Frill", accent:Lerp(Color3.new(1, 1, 1), 0.35),
                if pet.form == "frill" then Vector3.new(0.75, 0.72, 0.32) else Vector3.new(0.31, 0.48, 1.15),
                Vector3.new(x * 1.9, 0.3, 0.08))
        elseif pet.form ~= "shell" and pet.form ~= "crest" and pet.form ~= "spring" then
            accessory(body, "Ear", accent, Vector3.new(0.44, 0.78, 0.47), Vector3.new(x * 1.55, 0.67, 0.05))
        end
    end
    if pet.form == "tail" then
        accessory(body, "Tail", accent, Vector3.new(0.55, 0.62, 1.65), Vector3.new(0, 0.2, 1.15))
    end
    local trim = accent:Lerp(Color3.new(1, 1, 1), 0.4)
    if pet.form == "shell" then
        accessory(body, "Shell", trim, Vector3.new(1.43, 0.98, 1.4), Vector3.new(0, 0.49, 0.27))
    elseif pet.form == "crest" then
        accessory(body, "Crest", trim, Vector3.new(0.38, 1.08, 0.85), Vector3.new(0, 0.72, 0.05))
    elseif pet.form == "spring" then
        accessory(body, "Pom", trim, Vector3.new(0.72, 0.72, 0.72), Vector3.new(0, 0.31, 1.04))
    end
    if pet.mutated then
        local marking = accessory(body, "MutationMark", trim,
            Vector3.new(0.42, 0.38, 0.23), Vector3.new(0, 0.51, -0.7))
        marking.Material = Enum.Material.Neon
        local light = Instance.new("PointLight")
        light.Color = trim
        light.Brightness = 0.55
        light.Range = 5
        light.Parent = marking
    end
    if stormTrailUnlocked then
        local top = Instance.new("Attachment")
        top.Position = Vector3.new(0, 0.35, 0.5)
        top.Parent = body
        local bottom = Instance.new("Attachment")
        bottom.Position = Vector3.new(0, -0.35, 0.5)
        bottom.Parent = body
        local trail = Instance.new("Trail")
        trail.Attachment0 = top
        trail.Attachment1 = bottom
        trail.Color = ColorSequence.new(Color3.fromRGB(182, 150, 255), Color3.fromRGB(123, 208, 250))
        trail.Transparency = NumberSequence.new(0.15, 1)
        trail.FaceCamera = true
        trail.Lifetime = 0.35
        trail.Parent = body
    end
end

local function clearEgg(player, entry, outcome)
    if playtest and outcome and entry.egg then
        playtest:finish(player, outcome)
    end
    releasePrize(player, entry)
    entry.egg = nil
    entry.eggVault = nil
    entry.pickupAt = nil
    entry.abilityUsed = false
    entry.routeStage = 0
    entry.windFactor = nil
    entry.windPosition = nil
    entry.windSampleAt = nil
    player:SetAttribute("EggReturnTarget", nil)
    player:SetAttribute("WindEffect", nil)
    if entry.eggVisual then
        entry.eggVisual:Destroy()
        entry.eggVisual = nil
    end
    applySpeed(player, entry)
end

local function stopWeekly(player, entry)
    if not entry.weekly then
        return
    end
    local attempt = entry.weekly
    attempt.partConnection:Disconnect()
    if attempt.startRoot and attempt.startRoot.Parent then
        attempt.startRoot.Anchored = false
    end
    for part, group in pairs(attempt.collisionGroups) do
        if part.Parent then
            part.CollisionGroup = group
        end
    end
    if attempt.cargo then
        attempt.cargo:Destroy()
    end
    entry.weekly = nil
    entry.nextWeeklyStart = workspace:GetServerTimeNow() + 1
    player:SetAttribute("WeeklyStartsAt", nil)
    player:SetAttribute("WeeklyEndsAt", nil)
    player:SetAttribute("WeeklyStep", nil)
    player:SetAttribute("WeeklySplitText", nil)
    applySpeed(player, entry)
end

local cosmetics = table.clone(Rules.Trails)
for _, effect in ipairs(Rules.HatchEffects) do
    table.insert(cosmetics, effect)
end
for _, theme in ipairs(Rules.CampThemes) do
    table.insert(cosmetics, theme)
end
local cosmeticShop = CosmeticShop.start(cosmetics, Shared, MarketplaceService, inStudio, previewSeasonPass, seasonPassId, function(player)
    local entry = entries[player]
    if not closing and entry and not ProfileStore.expired(entry.session) then
        return entry
    end
    return nil
end)

bases = BaseService.new(workspace, {
    entries = entries,
    catalog = petCatalog,
    publish = publish,
    translate = translate,
    characterParts = characterParts,
    applySpeed = applySpeed,
    Profile = Profile,
    inStudio = inStudio,
    isClosing = function()
        return closing
    end,
    expired = function(session)
        return ProfileStore.expired(session)
    end,
    save = function(entry)
        -- A busy session skips the write, so wait for a real one before granting a purchase.
        while entry.session.busy do
            task.wait()
        end
        return ProfileStore.save(entry.session, Profile.snapshot(entry), false)
    end,
})

local function join(player)
    if closing or player.Parent ~= Players or entries[player] or loading[player] then
        return
    end
    local load = { cancelled = false }
    loading[player] = load
    pending += 1
    player.RespawnLocation = map.spawn
    player:SetAttribute("Notice", translate(player, "Загружаем прогресс…"))
    local function canContinue()
        return not closing and not load.cancelled and player.Parent == Players
    end
    local session, record, reason = ProfileStore.open(player, petCatalog, Rules, canContinue)
    loading[player] = nil
    if not session or not canContinue() then
        if session then
            ProfileStore.save(session, record, true)
        elseif canContinue() then
            warn("EGGSTRIDE: profile load failed", player.UserId, reason)
            player:Kick(translate(player, "Не удалось загрузить прогресс. Попробуй зайти чуть позже."))
        end
        pending -= 1
        return
    end

    local entry = {
        session = session,
        coins = record.coins,
        muteRunSounds = record.muteRunSounds,
        reduceCardMotion = record.reduceCardMotion,
        onboarding = record.onboarding,
        stormTrailUnlocked = record.stormTrailUnlocked,
        deliveryRecords = record.deliveryRecords,
        deliveries = record.deliveries,
        prizeWins = record.prizeWins,
        materials = record.materials,
        catalysts = record.catalysts,
        routeStage = 0,
        discoveries = record.discoveries,
        season = record.season,
        weeklyRecord = record.weeklyRecord,
        weeklyRewardWeek = record.weeklyRewardWeek,
        tier = record.tier,
        equippedTrail = record.equippedTrail,
        equippedHatchEffect = record.equippedHatchEffect,
        equippedCampTheme = record.equippedCampTheme,
        pet = petCatalog[record.equipped],
        delivered = false,
        ownedPets = {},
        nextEquipAt = 0,
        nextBreedAt = 0,
        nextMutationAt = 0,
        nextSeasonClaimAt = 0,
        nextSeasonPassAt = 0,
    }
    for id in pairs(record.owned) do
        entry.ownedPets[id] = petCatalog[id]
        player:SetAttribute("OwnsPet_" .. id, true)
    end
    for id in pairs(entry.discoveries) do
        publishRecipe(player, id, recipesByOffspring[id].parents)
    end
    for id, time in pairs(record.deliveryRecords) do
        player:SetAttribute("DeliveryRecord_" .. id, time)
    end
    for _, vault in ipairs(Rules.Vaults) do
        publishBiomeProgress(player, entry, vault.id)
    end
    for _, definition in ipairs(Rules.Prizes) do
        player:SetAttribute("PrizeWins_" .. definition.id, entry.prizeWins[definition.id] or 0)
    end
    local week = Rules.weekId(os.time())
    Season.rollover(entry, Rules.Season, week)
    publishSeason(player, entry)
    player:SetAttribute("WeeklyBest", Rules.weeklyBest(entry.weeklyRecord, week))
    player:SetAttribute("WeeklyRewardClaimed", (entry.weeklyRewardWeek or -1) >= week)
    if entry.weeklyRecord and entry.weeklyRecord.week == week and entry.weeklyRecord.rankedTime then
        task.defer(weeklyLeaderboard.submit, weeklyLeaderboard, player.UserId, player.Name, week, entry.weeklyRecord.rankedTime)
    end
    for attribute, field in pairs(preferences) do
        player:SetAttribute(attribute, entry[field])
    end
    entries[player] = entry
    bases.join(player, entry, record)
    if playtest then
        playtest:join(player, workspace:GetServerTimeNow(), record.onboarding == 0)
    end
    initPremium(player, entry)
    cosmeticShop.init(player, entry)
    pending -= 1
    advanceOnboarding(player, entry, 1)
    publish(player, entry, "")

    local function spawn(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        local root = character:WaitForChild("HumanoidRootPart", 10)
        if not humanoid or not root or player.Character ~= character or entries[player] ~= entry then
            return
        end
        if root.Position.X > Rules.GateX then
            character:PivotTo(map.spawn.CFrame + Vector3.new(0, 4, 0))
        end
        stopWeekly(player, entry)
        clearEgg(player, entry, "respawn")
        bases.dropStolen(player, entry, nil)
        publish(player, entry)
        cosmeticShop.apply(player, entry)
        if entry.pet then
            showPet(root, entry.pet, entry.stormTrailUnlocked)
        end
        humanoid.Died:Connect(function()
            if player.Character ~= character or entries[player] ~= entry then
                return
            end
            if entry.weekly then
                stopWeekly(player, entry)
                publish(player, entry, "")
                runFeedback:FireClient(player, "WeeklyStopped")
            end
            bases.dropStolen(player, entry, "Ты уронил украденного питомца.")
            local lost = entry.egg ~= nil
            clearEgg(player, entry, "fall")
            if lost then
                runFeedback:FireClient(player, "Fall")
            end
            publish(player, entry, if lost then "" else nil)
        end)
    end

    player.CharacterAdded:Connect(spawn)
    if player.Character then
        task.spawn(spawn, player.Character)
    end
end

local function withNearbyPlayer(prompt, action)
    prompt.Triggered:Connect(function(player)
        local entry = entries[player]
        local humanoid, root = characterParts(player)
        if closing or not entry or entry.weekly or ProfileStore.expired(entry.session) or not humanoid or humanoid.Health <= 0 or not root then
            return
        end
        if not prompt.Enabled or (root.Position - prompt.Parent.Position).Magnitude > prompt.MaxActivationDistance then
            return
        end
        action(player, entry, root)
    end)
end

local wasOpen = false
local currentRound = -1
local random = Random.new()
local roundEggs = {}
local prizeEggs = {}
local vineEndsAt = nil
local windDirection = 0
local switchedWind = false
local windSwitchEndsAt

local function showWind()
    World.showWind(map.windTrail, windDirection, switchedWind, windSwitchEndsAt ~= nil)
end

local function onBridge(root, bridge)
    local delta = root.Position - bridge.Position
    return math.abs(delta.X) <= bridge.Size.X / 2 and math.abs(delta.Z) <= bridge.Size.Z / 2
        and delta.Y >= 0 and delta.Y <= 9
end

local function updateReturnTarget(player, entry, root)
    local ability = entry.egg.ability
    local x = root.Position.X
    local target
    if ability == "anchor" then
        target = Rules.anchorReturnTarget(x, map.windTrail.meadowMarker.Position.X,
            map.windTrail.amberMarker.Position.X, onBridge(root, map.windTrail.part))
    elseif ability == "vine" then
        target = Rules.vineReturnTarget(x, map.vineExit.Position.X, map.vine.Position.X + map.vine.Size.X / 2,
            onBridge(root, map.vine), vineEndsAt ~= nil, entry.abilityUsed)
    end
    if player:GetAttribute("EggReturnTarget") ~= target then
        player:SetAttribute("EggReturnTarget", target)
    end
end

local function trackReturnBridge(entry, root, bridge)
    local relativeX = (root.Position.X - bridge.Position.X) / bridge.Size.X
    entry.routeStage = Rules.returnBridgeStage(entry.routeStage, relativeX)
end

local function updateWind(player, entry, humanoid, root, now, open)
    local factor = 1
    local effect
    if open and root and humanoid and humanoid.Health > 0 and not entry.weekly then
        local trail = map.windTrail.part
        local onTrail = onBridge(root, trail)
        if onTrail then
            local deltaTime = entry.windSampleAt and now - entry.windSampleAt
            if deltaTime and deltaTime < 0.1 then
                return
            end
            local paceX = if entry.windPosition then (root.Position.X - entry.windPosition) / deltaTime else 0
            entry.windSampleAt = now
            entry.windPosition = root.Position.X
            local anchor = entry.egg and entry.egg.ability == "anchor" and paceX < -1
            if anchor then
                trackReturnBridge(entry, root, trail)
            end
            factor = if anchor then Rules.WindTailwind else Rules.windFactor(windDirection, paceX)
            effect = if anchor then "Якорь ускоряет бег" elseif factor > 1 then "Попутный ветер"
                elseif factor < 1 then "Встречный ветер" else nil
        else
            entry.windPosition = nil
            entry.windSampleAt = nil
            if vineEndsAt and entry.egg and entry.egg.ability == "vine" and onBridge(root, map.vine) then
                factor = Rules.WindTailwind
                effect = "Лиана ускоряет бег"
                trackReturnBridge(entry, root, map.vine)
            elseif entry.routeStage == 1 then
                entry.routeStage = 0
            end
        end
    end
    if factor ~= (entry.windFactor or 1) then
        entry.windFactor = factor
        applySpeed(player, entry)
    end
    effect = if effect then translate(player, effect) else nil
    if player:GetAttribute("WindEffect") ~= effect then
        player:SetAttribute("WindEffect", effect)
    end
end

local function updateAbility(player, entry, root, now)
    if not entry.egg or entry.abilityUsed then
        return
    end
    local ability = entry.egg.ability
    if ability == "vine" and (root.Position - map.sprout.Position).Magnitude <= 7 then
        entry.abilityUsed = true
        vineEndsAt = now + Rules.Abilities.vine.duration
        World.showVine(map.vine, true)
        publish(player, entry, "Мост открыт. Беги по лиане.")
    elseif ability == "relay" and (root.Position - map.stormRelay.origin.Position).Magnitude <= 7 then
        entry.abilityUsed = true
        entry.routeStage = 2
        player.Character:PivotTo(map.stormRelay.destination)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        World.flashRelay(map.stormRelay)
        publish(player, entry, "Маяк перенёс тебя на Янтарный остров.")
    end
end

local function returnFromWeekly(player, entry, root)
    stopWeekly(player, entry)
    player.Character:PivotTo(map.spawn.CFrame + Vector3.new(0, 4, 0))
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

cancelWeekly.OnServerEvent:Connect(function(player, startsAt)
    local entry = entries[player]
    local attempt = entry and entry.weekly
    if closing or not attempt or startsAt ~= attempt.startsAt then
        return
    end
    local humanoid, root = characterParts(player)
    if not humanoid or humanoid.Health <= 0 or not root then
        return
    end

    returnFromWeekly(player, entry, root)
    publish(player, entry, "")
    runFeedback:FireClient(player, "WeeklyCancelled")
end)

local function finishWeekly(player, entry, root, now, week, completed)
    local attempt = entry.weekly
    returnFromWeekly(player, entry, root)
    if not completed then
        publish(player, entry, "")
        runFeedback:FireClient(player, "WeeklyStopped")
        return
    end

    local elapsed = now - attempt.startedAt
    local previous = Rules.weeklyBest(entry.weeklyRecord, week)
    local best = Rules.improvedDelivery(previous, elapsed, Rules.Weekly.duration)
    local previousRanked = previous and entry.weeklyRecord.rankedTime
    local rankedBest = attempt.rankable and Rules.improvedDelivery(previousRanked, elapsed, Rules.Weekly.duration)
    local reference = attempt.referenceSplits
    local finishTime = attempt.splits[#Rules.Weekly.order]
    local betterSplits = attempt.rankable and (not reference or finishTime < reference[#Rules.Weekly.order])
    if best or rankedBest or betterSplits then
        entry.weeklyRecord = {
            week = week, time = best or previous, rankedTime = rankedBest or previousRanked,
            rankedSplits = if betterSplits then attempt.splits else reference,
        }
        player:SetAttribute("WeeklyBest", entry.weeklyRecord.time)
    end
    if rankedBest then
        task.defer(weeklyLeaderboard.submit, weeklyLeaderboard, player.UserId, player.Name, week, rankedBest)
    end
    local milliseconds = math.round(elapsed * 1000)
    local rewardCoins = Rules.claimWeeklyReward(entry, week, milliseconds, attempt.rankable)
    if rewardCoins then
        player:SetAttribute("WeeklyRewardClaimed", true)
    end
    publish(player, entry, "")
    local result = if not attempt.rankable then "Вне рейтинга"
        elseif rankedBest then "Допущен к рейтингу"
        else "В рейтинге остаётся лучшее время"
    if attempt.rankable and Season.advance(entry, Rules.Season, week, "weekly") then
        publishSeason(player, entry)
    end
    runFeedback:FireClient(player, "WeeklyFinish", milliseconds, best ~= nil, result, rewardCoins)
end

local displayedWeek

local function hatch(player, entry, root, secondsLeft, now, week)
    local egg = entry.egg
    local vault = entry.eggVault
    local elapsed = now - entry.pickupAt
    local personalBest = Rules.improvedDelivery(entry.deliveryRecords[vault.id], elapsed)
    if personalBest then
        entry.deliveryRecords[vault.id] = personalBest
        player:SetAttribute("DeliveryRecord_" .. vault.id, personalBest)
    end
    local unlockedTrail = not entry.stormTrailUnlocked and Rules.stormTrialComplete(egg, entry.abilityUsed, secondsLeft)
    if unlockedTrail then
        entry.stormTrailUnlocked = true
    end
    local bonus = 0
    local definition = entry.prize
    local awardedPrize = definition and RoundPrize.deliver(prizes[definition.id], player)
    if awardedPrize then
        bonus = definition.bonus
        showPrize(definition, false, "Доставил: %s", player.DisplayName)
    end
    local routeCompleted = entry.routeStage == 2
    if playtest then
        playtest:finish(player, "delivered", now, secondsLeft, routeCompleted)
    end
    local catalystAwarded = Profile.awardCatalyst(entry, vault, entry.routeStage)
    clearEgg(player, entry)
    entry.delivered = true
    entry.coins += vault.coins + bonus
    local pet = if awardedPrize then
        Loot.prizePetForRoll(definition.pets, random:NextInteger(1, 1000))
        else Loot.hatchForRoll(vault, egg, random:NextInteger(1, 10000))
    local prizeId = if awardedPrize then definition.id else nil
    local isNew, materialGain = Profile.recordHatch(entry, vault, pet, prizeId)
    local seasonChanged = Season.advance(entry, Rules.Season, week, "delivery")
    if routeCompleted and Season.advance(entry, Rules.Season, week, "route") then
        seasonChanged = true
    end
    local recordChanged, recordXP = Season.recordDelivery(entry, Rules, week, vault, elapsed)
    if seasonChanged or recordChanged then
        publishSeason(player, entry)
    end
    publishBiomeProgress(player, entry, vault.id)
    if prizeId then
        player:SetAttribute("PrizeWins_" .. prizeId, entry.prizeWins[prizeId])
    end
    if isNew then
        player:SetAttribute("OwnsPet_" .. pet.id, true)
    end
    if not bases.addPet(player, entry, pet) then
        task.delay(4, function()
            if entries[player] == entry then
                publish(player, entry, "База заполнена: питомец только в коллекции. Купи слот на базе.")
            end
        end)
    end
    if not entry.pet or unlockedTrail then
        entry.pet = entry.pet or pet
        showPet(root, entry.pet, entry.stormTrailUnlocked)
    end
    advanceOnboarding(player, entry, 3)
    publish(player, entry, "")
    runFeedback:FireClient(player, "Hatch", pet.name, pet.rarity, vault.coins + bonus, isNew,
        if unlockedTrail then Rules.StormTrial.name else nil, personalBest, bonus,
        if materialGain > 0 then vault.id else nil, if catalystAwarded then vault.name else nil, recordXP)
end

local function syncRound()
    local now = workspace:GetServerTimeNow()
    local elapsed = now - startedAt
    local cycle = math.floor(elapsed / (Rules.PrepareSeconds + Rules.RunSeconds))
    local open, secondsLeft = Rules.clock(elapsed)
    local newRound = currentRound ~= cycle
    if newRound then
        currentRound = cycle
        for _, definition in ipairs(Rules.Prizes) do
            prizes[definition.id] = RoundPrize.new()
            prizeEggs[definition.id] = Loot.eggForRoll(definition.vaultIndex, random:NextInteger(1, 100))
            showPrize(definition, false, "")
        end
        windSwitchEndsAt = nil
        switchedWind = false
        windDirection = if windEnabled then Rules.windDirection(cycle) else 0
        showWind()
        for index in ipairs(Rules.Vaults) do
            roundEggs[index] = Loot.eggForRoll(index, random:NextInteger(1, 100))
        end
        for player, entry in pairs(entries) do
            entry.delivered = false
            local lost = entry.egg ~= nil
            clearEgg(player, entry, "timeout")
            if lost then
                runFeedback:FireClient(player, "Timeout")
            end
            publish(player, entry, if lost then "" else nil)
        end
    end
    if open ~= wasOpen or newRound then
        wasOpen = open
        if open then
            for _, definition in ipairs(Rules.Prizes) do
                showPrize(definition, true, "Приз на %s", definition.location, true)
            end
        end
        map.gate.CanCollide = not open
        map.gate.Transparency = if open then 1 else 0.35
    end
    if vineEndsAt and (not open or now >= vineEndsAt) then
        vineEndsAt = nil
        World.showVine(map.vine, false)
    end
    if windSwitchEndsAt and (not open or now >= windSwitchEndsAt) then
        windSwitchEndsAt = nil
        windDirection = Rules.windDirection(cycle)
        showWind()
    end
    local week = Rules.weekId(os.time())
    local weekChanged = displayedWeek ~= week
    displayedWeek = week
    weeklyLeaderboard:refresh(week)
    for player, entry in pairs(entries) do
        local humanoid, root = characterParts(player)
        if weekChanged then
            if Season.rollover(entry, Rules.Season, week) then
                publishSeason(player, entry)
            end
            player:SetAttribute("WeeklyBest", Rules.weeklyBest(entry.weeklyRecord, week))
            player:SetAttribute("WeeklyRewardClaimed", (entry.weeklyRewardWeek or -1) >= week)
        end
        local attempt = entry.weekly
        if attempt and root and humanoid and humanoid.Health > 0 then
            if attempt.week ~= week or ProfileStore.expired(entry.session) or (attempt.endsAt and now >= attempt.endsAt) then
                finishWeekly(player, entry, root, now, week, false)
            elseif attempt.startRoot then
                if now >= attempt.startsAt then
                    attempt.startRoot.Anchored = false
                    attempt.startRoot = nil
                    attempt.startedAt = now
                    attempt.endsAt = now + Rules.Weekly.duration
                    attempt.lastCheckpointAt = now
                    player:SetAttribute("WeeklyEndsAt", attempt.endsAt)
                    player:SetAttribute("WeeklyStep", attempt.step)
                end
            else
                local point = map.weekly.points[Rules.Weekly.order[attempt.step]].Position
                if (root.Position - point).Magnitude <= Rules.Weekly.checkpointRadius then
                    local span = (point - attempt.lastPoint).Magnitude
                    attempt.rankable = attempt.rankable
                        and Rules.weeklySplitPlausible(span, now - attempt.lastCheckpointAt, attempt.cargo ~= nil)
                    attempt.lastPoint = point
                    attempt.lastCheckpointAt = now
                    local splitTime = math.max(1, math.round((now - attempt.startedAt) * 1000))
                    attempt.splits[attempt.step] = splitTime
                    if attempt.step == #Rules.Weekly.order then
                        finishWeekly(player, entry, root, now, week, true)
                    else
                        if attempt.step == Rules.Weekly.eggStep then
                            attempt.cargo = accessory(root, "EggstrideTrainingEgg", Color3.fromRGB(182, 150, 255),
                                Vector3.new(1.8, 2.3, 1.8), Vector3.new(0, 0.5, -1.7))
                            applySpeed(player, entry)
                        end
                        local reference = attempt.rankable and attempt.referenceSplits
                        player:SetAttribute("WeeklySplitText",
                            Locale.weeklySplit(languageFor(player), splitTime, reference and reference[attempt.step]))
                        attempt.step += 1
                        player:SetAttribute("WeeklyStep", attempt.step)
                    end
                end
            end
        end
        if open and not entry.weekly and entry.egg and humanoid and humanoid.Health > 0 and root
            and not ProfileStore.expired(entry.session) then
            if (root.Position - map.hatch.Position).Magnitude <= 8 then
                hatch(player, entry, root, secondsLeft, now, week)
            else
                updateAbility(player, entry, root, now)
                updateReturnTarget(player, entry, root)
            end
        end
        updateWind(player, entry, humanoid, root, now, open)
        if not open and root and humanoid and humanoid.Health > 0 and root.Position.X > Rules.GateX then
            player.Character:PivotTo(map.spawn.CFrame + Vector3.new(0, 4, 0))
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end
    return open, secondsLeft, now
end

withNearbyPlayer(map.weekly.prompt, function(player, entry, root)
    if root.Anchored then
        return
    end
    if entry.stolen then
        publish(player, entry, "Руки заняты: сначала донеси груз.")
        return
    end
    if entry.egg then
        publish(player, entry, "Сначала доставь яйцо в инкубатор.")
        return
    end
    local now = workspace:GetServerTimeNow()
    if entry.nextWeeklyStart and now < entry.nextWeeklyStart then
        return
    end
    local character = player.Character
    local week = Rules.weekId(os.time())
    local attempt = {
        startsAt = now + Rules.Weekly.countdown, startRoot = root, week = week,
        step = 1, collisionGroups = {}, rankable = true, splits = {},
        referenceSplits = if Rules.weeklyBest(entry.weeklyRecord, week) then entry.weeklyRecord.rankedSplits else nil,
        lastPoint = map.weekly.points.Finish.Position,
    }
    local function setRunnerCollision(part)
        if part:IsA("BasePart") and not attempt.collisionGroups[part] then
            attempt.collisionGroups[part] = part.CollisionGroup
            part.CollisionGroup = weeklyGroup
        end
    end
    for _, part in ipairs(character:GetDescendants()) do
        setRunnerCollision(part)
    end
    attempt.partConnection = character.DescendantAdded:Connect(setRunnerCollision)
    entry.weekly = attempt
    local start = map.weekly.points.Finish.Position + Vector3.new(0, 3.2, 0)
    player.Character:PivotTo(CFrame.lookAt(start, start + Vector3.new(-1, 0, 0)))
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.Anchored = true
    applySpeed(player, entry)
    player:SetAttribute("WeeklyStartsAt", attempt.startsAt)
    publish(player, entry, "")
end)

local function pickUp(player, entry, root, vaultIndex, definition)
    if entry.stolen then
        publish(player, entry, "Руки заняты: сначала донеси груз.")
        return
    end
    local open, _, now = syncRound()
    if not Rules.canCollect(entry.egg ~= nil, open, entry.delivered) then
        return
    end
    local vault = Rules.Vaults[vaultIndex]
    if not Rules.canUseVault(entry.tier, vault) then
        publish(player, entry, "Купи ускорение в лагере, чтобы забрать это яйцо.")
        return
    end
    if definition then
        if not RoundPrize.claim(prizes[definition.id], player) then
            if playtest then
                playtest:missPrize(vault.id)
            end
            return
        end
        entry.prize = definition
        showPrize(definition, false, "%s забрал приз", player.DisplayName)
    end
    entry.egg = if definition then prizeEggs[definition.id] else roundEggs[vaultIndex]
    entry.pickupAt = now
    advanceOnboarding(player, entry, Rules.onboardingAfterPickup(entry.onboarding))
    entry.eggVault = vault
    if playtest then
        playtest:pickUp(player, vault.id, definition ~= nil, now)
    end
    entry.eggVisual = accessory(root, "EggstrideEgg", World.VaultColors[vaultIndex],
        Vector3.new(2.15, 2.7, 2.15), Vector3.new(0, 0.65, -1.8))
    applySpeed(player, entry)
    publish(player, entry, "")
end

for index, display in ipairs(map.vaults) do
    withNearbyPlayer(display.prompt, function(player, entry, root)
        pickUp(player, entry, root, index)
    end)
end

for _, definition in ipairs(Rules.Prizes) do
    withNearbyPlayer(map.prizes[definition.id].prompt, function(player, entry, root)
        pickUp(player, entry, root, definition.vaultIndex, definition)
    end)
end

withNearbyPlayer(map.windTrail.leverPrompt, function(player, entry)
    if not syncRound() then
        return
    end
    if switchedWind then
        publish(player, entry, "Рычаг уже использован в этом раунде.")
        return
    end
    if windDirection ~= 1 then
        publish(player, entry, "На пути домой нет встречного ветра.")
        return
    end

    local trail = map.windTrail.part
    local amberEdge = trail.Position.X + trail.Size.X / 2
    local amberEntrance = Vector3.new(amberEdge, 0, trail.Position.Z)
    local carrier
    for other, otherEntry in pairs(entries) do
        if other ~= player and otherEntry.egg and not ProfileStore.expired(otherEntry.session) then
            local humanoid, root = characterParts(other)
            if humanoid and humanoid.Health > 0 and root and root.Position.X >= amberEdge
                and (root.Position - amberEntrance).Magnitude <= Rules.WindSwitch.partnerRadius then
                carrier = other
                break
            end
        end
    end
    if not Rules.canSwitchWind(windDirection, switchedWind, carrier ~= nil) then
        publish(player, entry, "Дождись игрока с яйцом у янтарного входа на тропу.")
        return
    end

    switchedWind = true
    windSwitchEndsAt = workspace:GetServerTimeNow() + Rules.WindSwitch.duration
    windDirection = -1
    showWind()
    publish(player, entry, "Ты развернул ветер на %d сек.", Rules.WindSwitch.duration)
    publish(carrier, entries[carrier], "Ветер развернули. Беги домой по короткой тропе!")
end)

withNearbyPlayer(map.shop, function(player, entry)
    local cost, vault, missing = Rules.nextSpeedUpgrade(entry.tier, entry.coins)
    if not cost then
        publish(player, entry, "Ты достиг максимальной скорости.")
    elseif missing > 0 then
        publish(player, entry, "Для улучшения нужно ещё %d монет.", missing)
    else
        entry.coins -= cost
        entry.tier += 1
        applySpeed(player, entry)
        if vault then
            if playtest then
                playtest:upgrade(player, vault.id, workspace:GetServerTimeNow())
            end
            publish(player, entry, "Открыт %s остров", translate(player, vault.name))
        else
            publish(player, entry, "Скорость повышена до уровня %d.", entry.tier)
        end
    end
end)

updatePreference.OnServerEvent:Connect(function(player, attribute, value)
    local entry = entries[player]
    if closing or not entry or ProfileStore.expired(entry.session)
        or typeof(attribute) ~= "string" or typeof(value) ~= "boolean" then
        return
    end
    local field = preferences[attribute]
    if field and entry[field] ~= value then
        entry[field] = value
        player:SetAttribute(attribute, value)
    end
end)

breedPet.OnServerEvent:Connect(function(player, firstId, secondId)
    local entry = entries[player]
    if closing or not entry or entry.weekly or ProfileStore.expired(entry.session)
        or typeof(firstId) ~= "string" or #firstId > 32
        or typeof(secondId) ~= "string" or #secondId > 32 or firstId == secondId
        or not entry.ownedPets[firstId] or not entry.ownedPets[secondId] then
        return
    end

    local now = os.clock()
    if now < entry.nextBreedAt then
        return
    end
    entry.nextBreedAt = now + 0.25

    local recipe = Nursery.find(recipesByPair, firstId, secondId)
    if not recipe then
        breedPet:FireClient(player, firstId, secondId, "miss")
        return
    end
    local offspring = recipe.offspring
    local vaultId = recipe.vault.id
    if entry.discoveries[offspring.id] then
        breedPet:FireClient(player, firstId, secondId, "known", offspring.name)
    elseif Profile.breed(entry, recipe) then
        player:SetAttribute("OwnsPet_" .. offspring.id, true)
        player:SetAttribute("Material_" .. vaultId, entry.materials[vaultId] or 0)
        publishRecipe(player, offspring.id, recipe.parents)
        breedPet:FireClient(player, firstId, secondId, "found", offspring.name)
    else
        breedPet:FireClient(player, firstId, secondId, "materials")
    end
end)

mutatePet.OnServerEvent:Connect(function(player, petId)
    local entry = entries[player]
    if closing or not entry or entry.weekly or ProfileStore.expired(entry.session)
        or typeof(petId) ~= "string" or #petId > 32 then
        return
    end
    local now = os.clock()
    if now < entry.nextMutationAt then
        return
    end
    entry.nextMutationAt = now + 0.25

    local mutation = mutationsByPet[petId]
    if mutation and Profile.mutatePet(entry, mutation) then
        local vaultId = mutation.vault.id
        player:SetAttribute("OwnsPet_" .. petId, true)
        player:SetAttribute("Catalyst_" .. vaultId, entry.catalysts[vaultId])
        publish(player, entry, "Новая форма: %s.", translate(player, mutation.pet.name))
    end
end)

seasonPass.OnServerEvent:Connect(function(player)
    local entry = entries[player]
    if closing or not entry or ProfileStore.expired(entry.session) then
        return
    end
    local now = os.clock()
    if now < entry.nextSeasonPassAt then
        return
    end
    entry.nextSeasonPassAt = now + 2

    if previewSeasonPass and entry.premiumStatus == "preview" then
        setPremiumStatus(player, entry, "previewOwned")
    elseif not inStudio and seasonPassId then
        if entry.premiumStatus == "error" then
            refreshPremium(player, entry)
        elseif entry.premiumStatus == "locked" then
            setPremiumStatus(player, entry, "prompting")
            local ok = pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, seasonPassId)
            if not ok and entries[player] == entry and entry.premiumStatus == "prompting" then
                setPremiumStatus(player, entry, "error")
            end
        end
    end
end)

if not inStudio and seasonPassId then
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
        local entry = entries[player]
        if closing or not entry or passId ~= seasonPassId or ProfileStore.expired(entry.session) then
            return
        end
        if purchased then
            setPremiumStatus(player, entry, "owned")
        elseif entry.premiumStatus == "prompting" then
            setPremiumStatus(player, entry, "locked")
        end
    end)
end

claimSeason.OnServerEvent:Connect(function(player, index, premium)
    local entry = entries[player]
    local rewards = if premium == true then Rules.Season.premiumRewards else Rules.Season.rewards
    if closing or not entry or ProfileStore.expired(entry.session)
        or (premium ~= nil and typeof(premium) ~= "boolean")
        or typeof(index) ~= "number" or index < 1 or index > #rewards or index % 1 ~= 0 then
        return
    end
    local now = os.clock()
    if now < entry.nextSeasonClaimAt then
        return
    end
    entry.nextSeasonClaimAt = now + 0.2

    local week = Rules.weekId(os.time())
    local claimed, rolledOver = Season.claim(entry, Rules.Season, week, index, premium)
    if not claimed then
        if rolledOver then
            publishSeason(player, entry)
        end
        return
    end
    local reward = rewards[index]
    if reward.pet then
        player:SetAttribute("OwnsPet_" .. reward.pet.id, true)
    elseif reward.material then
        publishBiomeProgress(player, entry, reward.material)
    end
    publishSeason(player, entry)
    publish(player, entry, "Награда сезона: %s.", translate(player, reward.label))
end)

equipPet.OnServerEvent:Connect(function(player, petId)
    local entry = entries[player]
    if closing or not entry or ProfileStore.expired(entry.session) or typeof(petId) ~= "string" or #petId > 32 then
        return
    end
    local now = os.clock()
    if now < entry.nextEquipAt then
        return
    end
    entry.nextEquipAt = now + 0.25

    local pet = entry.ownedPets[petId]
    if not pet or pet == entry.pet then
        return
    end
    entry.pet = pet
    local humanoid, root = characterParts(player)
    if humanoid and humanoid.Health > 0 and root then
        showPet(root, pet, entry.stormTrailUnlocked)
    end
    publish(player, entry, "Спутник выбран: %s.", translate(player, pet.name))
end)

syncRound()

Players.PlayerAdded:Connect(join)
Players.PlayerRemoving:Connect(leave)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(join, player)
end

game:BindToClose(function()
    closing = true
    for player in pairs(entries) do
        task.defer(leave, player)
    end
    task.wait()
    local deadline = os.clock() + 25
    while pending > 0 and os.clock() < deadline do
        task.wait()
    end
end)

task.spawn(function()
    while not closing do
        task.wait(45)
        if closing then
            break
        end
        for player, entry in pairs(entries) do
            task.defer(function()
                if entries[player] ~= entry then
                    return
                end
                local ok, reason = ProfileStore.save(entry.session, Profile.snapshot(entry), false)
                if entries[player] ~= entry or ok then
                    return
                end
                warn("EGGSTRIDE: autosave failed", player.UserId, reason)
                if reason == "lost" or ProfileStore.expired(entry.session) then
                    player:Kick(translate(player, "Сохранение больше недоступно. Перезайди, чтобы продолжить."))
                end
            end)
        end
    end
end)

while true do
    syncRound()
    task.wait(0.15)
end
