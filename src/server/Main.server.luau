local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Eggstride")
local Rules = require(Shared.Rules)
local World = require(script.Parent.World)
local Profile = require(script.Parent.Profile)
local ProfileStore = require(script.Parent.ProfileStore)
local WeeklyLeaderboard = require(script.Parent.WeeklyLeaderboard)

local petCatalog = {}
for _, vault in ipairs(Rules.Vaults) do
    for _, pet in pairs(vault.pets) do
        petCatalog[pet.id] = pet
    end
end

local weeklyGroup = "EggstrideWeeklyRunners"
if not workspace:IsCollisionGroupRegistered(weeklyGroup) then
    workspace:RegisterCollisionGroup(weeklyGroup)
end
workspace:CollisionGroupSetCollidable(weeklyGroup, weeklyGroup, false)

local map = World.build(Rules)
local startedAt = workspace:GetServerTimeNow()
local round = Instance.new("Folder")
round.Name = "Round"
round:SetAttribute("StartedAt", startedAt)
local targets = { Gate = map.gate, FirstEgg = map.vaults[1].part, Hatch = map.hatch.Parent }
for name, point in pairs(map.weekly.points) do
    targets["Weekly" .. name] = point
end
for name, part in pairs(targets) do
    local marker = Instance.new("ObjectValue")
    marker.Name = name
    marker.Value = part
    marker.Parent = round
end
local weeklyLeaderboard = WeeklyLeaderboard.new(round, Rules)
round.Parent = Shared

local equipPet = Instance.new("RemoteEvent")
equipPet.Name = "EquipPet"
equipPet.Parent = Shared

local runFeedback = Instance.new("RemoteEvent")
runFeedback.Name = "RunFeedback"
runFeedback.Parent = Shared

local updatePreference = Instance.new("RemoteEvent")
updatePreference.Name = "UpdatePreference"
updatePreference.Parent = Shared
local preferences = {
    MuteRunSounds = "muteRunSounds",
    ReduceCardMotion = "reduceCardMotion",
}

local entries = {}
local loading = {}
local closing = false
local pending = 0
local logAnalytics = not RunService:IsStudio()
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
            humanoid.WalkSpeed = Rules.speed(entry.tier, entry.egg ~= nil) * (entry.windFactor or 1)
        end
    end
end

local function publish(player, entry, message)
    player:SetAttribute("OnboardingStep", entry.onboarding)
    player:SetAttribute("StormTrailUnlocked", entry.stormTrailUnlocked)
    player:SetAttribute("Coins", entry.coins)
    player:SetAttribute("SpeedTier", entry.tier)
    player:SetAttribute("EquippedPetId", entry.pet and entry.pet.id or "")
    player:SetAttribute("EquippedPet", entry.pet and (entry.pet.name .. " · " .. entry.pet.rarity) or "")
    player:SetAttribute("EggName", entry.egg and entry.egg.name or "")
    player:SetAttribute("EggAbility", entry.egg and not entry.abilityUsed and entry.egg.ability or "")
    player:SetAttribute("Delivered", entry.delivered)
    if message then
        player:SetAttribute("Notice", message)
    end
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
    local body = accessory(root, "EggstridePet", accent, Vector3.new(1.9, 1.45, 1.7), Vector3.new(2.6, 0, 2.4))
    for _, x in ipairs({ -0.43, 0.43 }) do
        accessory(body, "Eye", Color3.fromRGB(46, 40, 61), Vector3.new(0.21, 0.27, 0.21), Vector3.new(x, 0.1, -0.72))
        accessory(body, "Ear", accent, Vector3.new(0.44, 0.78, 0.47), Vector3.new(x * 1.55, 0.67, 0.05))
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

local function clearEgg(player, entry)
    entry.egg = nil
    entry.eggVault = nil
    entry.pickupAt = nil
    entry.abilityUsed = false
    entry.anchorEndsAt = nil
    entry.windFactor = nil
    entry.windPosition = nil
    entry.windSampleAt = nil
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
    player:SetAttribute("WeeklyEndsAt", nil)
    player:SetAttribute("WeeklyStep", nil)
    applySpeed(player, entry)
end

local function join(player)
    if closing or player.Parent ~= Players or entries[player] or loading[player] then
        return
    end
    local load = { cancelled = false }
    loading[player] = load
    pending += 1
    player.RespawnLocation = map.spawn
    player:SetAttribute("Notice", "Загружаем прогресс…")
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
            player:Kick("Не удалось загрузить прогресс. Попробуй зайти чуть позже.")
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
        weeklyRecord = record.weeklyRecord,
        tier = record.tier,
        pet = petCatalog[record.equipped],
        delivered = false,
        ownedPets = {},
        nextEquipAt = 0,
    }
    for id in pairs(record.owned) do
        entry.ownedPets[id] = petCatalog[id]
        player:SetAttribute("OwnsPet_" .. id, true)
    end
    for id, time in pairs(record.deliveryRecords) do
        player:SetAttribute("DeliveryRecord_" .. id, time)
    end
    local week = Rules.weekId(os.time())
    player:SetAttribute("WeeklyBest", Rules.weeklyBest(entry.weeklyRecord, week))
    if entry.weeklyRecord and entry.weeklyRecord.week == week and entry.weeklyRecord.rankedTime then
        task.defer(weeklyLeaderboard.submit, weeklyLeaderboard, player.UserId, player.Name, week, entry.weeklyRecord.rankedTime)
    end
    for attribute, field in pairs(preferences) do
        player:SetAttribute(attribute, entry[field])
    end
    entries[player] = entry
    pending -= 1
    advanceOnboarding(player, entry, 1)
    publish(player, entry, "Заработай скорость в лагере или сразу попробуй ближайший остров.")

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
        clearEgg(player, entry)
        publish(player, entry)
        if entry.pet then
            showPet(root, entry.pet, entry.stormTrailUnlocked)
        end
        humanoid.Died:Connect(function()
            if player.Character ~= character or entries[player] ~= entry then
                return
            end
            if entry.weekly then
                stopWeekly(player, entry)
                publish(player, entry, "Забег недели прерван. Попробуй ещё раз из лагеря.")
            end
            local lost = entry.egg ~= nil
            clearEgg(player, entry)
            if lost then
                runFeedback:FireClient(player, "Fall")
            end
            publish(player, entry, if lost then "Яйцо потеряно. Следующий забег начнётся в лагере." else nil)
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
        if (root.Position - prompt.Parent.Position).Magnitude > prompt.MaxActivationDistance then
            return
        end
        action(player, entry, root)
    end)
end

local wasOpen = false
local currentRound = -1
local random = Random.new()
local roundEggs = {}
local vineEndsAt = nil
local windEnabled = workspace:GetAttribute("WindTrailEnabled") ~= false
local windDirection = 0
local switchedWind = false
local windSwitchEndsAt

local function showWind()
    World.showWind(map.windTrail, windDirection, switchedWind, windSwitchEndsAt ~= nil)
end

local function updateWind(player, entry, humanoid, root, now, open)
    local factor = 1
    local protected = entry.anchorEndsAt ~= nil and now < entry.anchorEndsAt
    if open and windDirection ~= 0 and root and humanoid and humanoid.Health > 0 then
        local trail = map.windTrail.part
        local offset = root.Position - trail.Position
        if math.abs(offset.X) <= trail.Size.X / 2 - 2
            and math.abs(offset.Z) <= trail.Size.Z / 2 and offset.Y >= 0 and offset.Y <= 9 then
            if entry.windPosition then
                local deltaTime = now - entry.windSampleAt
                if deltaTime < 0.1 then
                    return
                end
                factor = Rules.windFactor(windDirection, (root.Position.X - entry.windPosition) / deltaTime, protected)
            end
            entry.windPosition = root.Position.X
            entry.windSampleAt = now
        else
            entry.windPosition = nil
        end
    else
        entry.windPosition = nil
    end
    if factor ~= (entry.windFactor or 1) then
        entry.windFactor = factor
        applySpeed(player, entry)
    end
    local effect = if factor > 1 then "Попутный ветер"
        elseif factor < 1 then "Встречный ветер"
        elseif protected then "Якорь ветра активен"
        else nil
    if player:GetAttribute("WindEffect") ~= effect then
        player:SetAttribute("WindEffect", effect)
    end
end

local function finishWeekly(player, entry, root, now, week, completed)
    local attempt = entry.weekly
    stopWeekly(player, entry)
    player.Character:PivotTo(map.spawn.CFrame + Vector3.new(0, 4, 0))
    root.AssemblyLinearVelocity = Vector3.zero
    if not completed then
        publish(player, entry, "Забег недели истёк. Попробуй снова из лагеря.")
        return
    end

    local elapsed = now - attempt.startedAt
    local previous = Rules.weeklyBest(entry.weeklyRecord, week)
    local best = Rules.improvedDelivery(previous, elapsed, Rules.Weekly.duration)
    local previousRanked = previous and entry.weeklyRecord.rankedTime
    local rankedBest = attempt.rankable and Rules.improvedDelivery(previousRanked, elapsed, Rules.Weekly.duration)
    if best or rankedBest then
        entry.weeklyRecord = { week = week, time = best or previous, rankedTime = rankedBest or previousRanked }
        player:SetAttribute("WeeklyBest", entry.weeklyRecord.time)
    end
    if rankedBest then
        task.defer(weeklyLeaderboard.submit, weeklyLeaderboard, player.UserId, player.Name, week, rankedBest)
    end
    local message = if best then "Личный рекорд недели · " else "Забег завершён · "
    local qualification = if attempt.rankable then "" else " · вне рейтинга"
    publish(player, entry, message .. Rules.deliveryTimeText(math.round(elapsed * 1000)) .. qualification)
end

local displayedWeek

local function syncRound()
    local now = workspace:GetServerTimeNow()
    local elapsed = now - startedAt
    local cycle = math.floor(elapsed / (Rules.PrepareSeconds + Rules.RunSeconds))
    local open, secondsLeft = Rules.clock(elapsed)
    if currentRound ~= cycle then
        currentRound = cycle
        windSwitchEndsAt = nil
        switchedWind = false
        windDirection = if windEnabled then Rules.windDirection(cycle) else 0
        showWind()
        for index, vault in ipairs(Rules.Vaults) do
            local egg = Rules.eggForRoll(vault, random:NextInteger(1, 100))
            roundEggs[index] = egg
            World.showEgg(map.vaults[index], egg, Rules)
        end
        for player, entry in pairs(entries) do
            entry.delivered = false
            local lost = entry.egg ~= nil
            clearEgg(player, entry)
            if lost then
                runFeedback:FireClient(player, "Timeout")
            end
            publish(player, entry, if lost then "Время вышло. Вынеси яйцо в следующем забеге." else nil)
        end
    end
    if open ~= wasOpen then
        wasOpen = open
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
            player:SetAttribute("WeeklyBest", Rules.weeklyBest(entry.weeklyRecord, week))
        end
        local attempt = entry.weekly
        if attempt and root and humanoid and humanoid.Health > 0 then
            if now >= attempt.endsAt or attempt.week ~= week or ProfileStore.expired(entry.session) then
                finishWeekly(player, entry, root, now, week, false)
            else
                local point = map.weekly.points[Rules.Weekly.order[attempt.step]].Position
                if (root.Position - point).Magnitude <= Rules.Weekly.checkpointRadius then
                    local span = (point - attempt.lastPoint).Magnitude
                    attempt.rankable = attempt.rankable
                        and Rules.weeklySplitPlausible(span, now - attempt.lastCheckpointAt, attempt.cargo ~= nil)
                    attempt.lastPoint = point
                    attempt.lastCheckpointAt = now
                    if attempt.step == #Rules.Weekly.order then
                        finishWeekly(player, entry, root, now, week, true)
                    else
                        if attempt.step == Rules.Weekly.eggStep then
                            attempt.cargo = accessory(root, "EggstrideTrainingEgg", Color3.fromRGB(182, 150, 255),
                                Vector3.new(1.8, 2.3, 1.8), Vector3.new(0, 0.5, -1.7))
                            applySpeed(player, entry)
                        end
                        attempt.step += 1
                        player:SetAttribute("WeeklyStep", attempt.step)
                    end
                end
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
    if entry.egg then
        publish(player, entry, "Сначала доставь яйцо в инкубатор.")
        return
    end
    local now = workspace:GetServerTimeNow()
    if entry.nextWeeklyStart and now < entry.nextWeeklyStart then
        return
    end
    local character = player.Character
    local attempt = {
        startedAt = now, endsAt = now + Rules.Weekly.duration, week = Rules.weekId(os.time()),
        step = 1, collisionGroups = {}, rankable = true,
        lastPoint = map.weekly.points.Finish.Position, lastCheckpointAt = now,
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
    applySpeed(player, entry)
    player:SetAttribute("WeeklyStep", attempt.step)
    player:SetAttribute("WeeklyEndsAt", attempt.endsAt)
    publish(player, entry, "Пройди метки, возьми яйцо и вернись на финиш.")
end)

for index, display in ipairs(map.vaults) do
    local vault = Rules.Vaults[index]
    withNearbyPlayer(display.prompt, function(player, entry, root)
        local open, _, now = syncRound()
        if not Rules.canCollect(entry.tier, vault, entry.egg ~= nil, open, entry.delivered) then
            if open and entry.tier < vault.tier then
                publish(player, entry, "Для этого яйца нужен уровень скорости " .. vault.tier .. ".")
            end
            return
        end
        local egg = roundEggs[index]
        entry.egg = egg
        entry.pickupAt = now
        advanceOnboarding(player, entry, Rules.onboardingAfterPickup(entry.onboarding))
        entry.eggVault = vault
        entry.eggVisual = accessory(root, "EggstrideEgg", World.variantColor(egg),
            Vector3.new(2.15, 2.7, 2.15), Vector3.new(0, 0.65, -1.8))
        applySpeed(player, entry)
        local ability = Rules.Abilities[egg.ability]
        publish(player, entry, if ability then Rules.abilityEffect(ability)
            else "Возвращайся в лагерь и подойди к инкубатору.")
    end)
end

withNearbyPlayer(map.vinePrompt, function(player, entry)
    if not syncRound() or not entry.egg or entry.egg.ability ~= "vine" or entry.abilityUsed then
        return
    end
    if vineEndsAt then
        publish(player, entry, "Мост уже открыт. Можно бежать!")
        return
    end
    entry.abilityUsed = true
    vineEndsAt = workspace:GetServerTimeNow() + Rules.Abilities.vine.duration
    World.showVine(map.vine, true)
    publish(player, entry, "Мост из лиан открыт на " .. Rules.Abilities.vine.duration .. " сек.")
end)

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
    local anchor = map.windTrail.anchorPrompt.Parent.Position
    local carrier
    for other, otherEntry in pairs(entries) do
        if other ~= player and otherEntry.egg and not ProfileStore.expired(otherEntry.session) then
            local humanoid, root = characterParts(other)
            if humanoid and humanoid.Health > 0 and root and root.Position.X >= amberEdge
                and (root.Position - anchor).Magnitude <= Rules.WindSwitch.partnerRadius then
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
    publish(player, entry, "Ты развернул ветер на " .. Rules.WindSwitch.duration .. " сек.")
    publish(carrier, entries[carrier], "Ветер развернули. Беги домой по короткой тропе!")
end)

withNearbyPlayer(map.windTrail.anchorPrompt, function(player, entry)
    if not syncRound() then
        return
    end
    if not entry.egg or entry.egg.ability ~= "anchor" then
        publish(player, entry, "Нужно яйцо с Янтарного острова.")
        return
    end
    if entry.abilityUsed then
        publish(player, entry, "Якорь уже использован с этим яйцом.")
        return
    end
    if windDirection ~= 1 then
        publish(player, entry, "На пути домой нет встречного ветра.")
        return
    end
    entry.abilityUsed = true
    entry.anchorEndsAt = workspace:GetServerTimeNow() + Rules.Abilities.anchor.duration
    publish(player, entry, "Якорь активен. Беги по короткой тропе.")
end)

withNearbyPlayer(map.stormRelay.prompt, function(player, entry, root)
    if not syncRound() then
        return
    end
    if not entry.egg or entry.egg.ability ~= "relay" then
        publish(player, entry, "Нужно яйцо с Грозового острова.")
        return
    end
    if entry.abilityUsed then
        publish(player, entry, "Разряд уже использован с этим яйцом.")
        return
    end
    entry.abilityUsed = true
    player.Character:PivotTo(map.stormRelay.destination)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    World.flashRelay(map.stormRelay)
    publish(player, entry, "Ты на Янтарном острове. Донеси яйцо в лагерь.")
end)

withNearbyPlayer(map.hatch, function(player, entry, root)
    local open, secondsLeft, now = syncRound()
    if not open or not entry.egg then
        return
    end
    local egg = entry.egg
    local vault = entry.eggVault
    local personalBest = Rules.improvedDelivery(entry.deliveryRecords[vault.id], now - entry.pickupAt)
    if personalBest then
        entry.deliveryRecords[vault.id] = personalBest
        player:SetAttribute("DeliveryRecord_" .. vault.id, personalBest)
    end
    local unlockedTrail = not entry.stormTrailUnlocked and Rules.stormTrialComplete(egg, entry.abilityUsed, secondsLeft)
    if unlockedTrail then
        entry.stormTrailUnlocked = true
    end
    clearEgg(player, entry)
    entry.delivered = true
    entry.coins += vault.coins
    local pet = Rules.hatchForRoll(vault, egg, random:NextInteger(1, 100))
    local isNew = entry.ownedPets[pet.id] == nil
    if isNew then
        entry.ownedPets[pet.id] = pet
        player:SetAttribute("OwnsPet_" .. pet.id, true)
    end
    if not entry.pet or unlockedTrail then
        entry.pet = entry.pet or pet
        showPet(root, entry.pet, entry.stormTrailUnlocked)
    end
    advanceOnboarding(player, entry, 3)
    local result = if isNew then "Новый в журнале: " else "Вылупился "
    publish(player, entry, result .. pet.name .. " · " .. pet.rarity .. " · +" .. vault.coins .. " монет.")
    runFeedback:FireClient(player, "Hatch", pet.name, pet.rarity, vault.coins, isNew,
        if unlockedTrail then Rules.StormTrial.name else nil, personalBest)
end)

withNearbyPlayer(map.shop, function(player, entry)
    local cost = Rules.UpgradeCosts[entry.tier]
    if not cost then
        publish(player, entry, "Ты достиг максимальной скорости.")
    elseif entry.coins < cost then
        publish(player, entry, "Следующий уровень скорости стоит " .. cost .. " монет.")
    else
        entry.coins -= cost
        entry.tier += 1
        applySpeed(player, entry)
        publish(player, entry, "Скорость повышена до уровня " .. entry.tier .. ".")
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
    publish(player, entry, "Спутник выбран: " .. pet.name .. ".")
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
                    player:Kick("Сохранение больше недоступно. Перезайди, чтобы продолжить.")
                end
            end)
        end
    end
end)

while true do
    syncRound()
    task.wait(0.15)
end
