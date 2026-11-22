local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Eggstride")
local Rules = require(Shared.Rules)
local World = require(script.Parent.World)
local Profile = require(script.Parent.Profile)
local ProfileStore = require(script.Parent.ProfileStore)

local petCatalog = {}
for _, vault in ipairs(Rules.Vaults) do
    for _, pet in pairs(vault.pets) do
        petCatalog[pet.id] = pet
    end
end

local map = World.build(Rules)
local startedAt = workspace:GetServerTimeNow()
local round = Instance.new("Folder")
round.Name = "Round"
round:SetAttribute("StartedAt", startedAt)
local targets = { Gate = map.gate, FirstEgg = map.vaults[1].part, Hatch = map.hatch.Parent }
for name, part in pairs(targets) do
    local marker = Instance.new("ObjectValue")
    marker.Name = name
    marker.Value = part
    marker.Parent = round
end
round.Parent = Shared

local equipPet = Instance.new("RemoteEvent")
equipPet.Name = "EquipPet"
equipPet.Parent = Shared

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
        humanoid.WalkSpeed = Rules.speed(entry.tier, entry.egg ~= nil)
    end
end

local function publish(player, entry, message)
    player:SetAttribute("OnboardingStep", entry.onboarding)
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

local function showPet(root, pet)
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
end

local function clearEgg(player, entry)
    entry.egg = nil
    entry.eggVault = nil
    entry.abilityUsed = false
    if entry.eggVisual then
        entry.eggVisual:Destroy()
        entry.eggVisual = nil
    end
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
        onboarding = record.onboarding,
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
        clearEgg(player, entry)
        publish(player, entry)
        if entry.pet then
            showPet(root, entry.pet)
        end
        humanoid.Died:Connect(function()
            if player.Character ~= character or entries[player] ~= entry then
                return
            end
            local lost = entry.egg ~= nil
            clearEgg(player, entry)
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
        if closing or not entry or ProfileStore.expired(entry.session) or not humanoid or humanoid.Health <= 0 or not root then
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

local function syncRound()
    local now = workspace:GetServerTimeNow()
    local elapsed = now - startedAt
    local cycle = math.floor(elapsed / (Rules.PrepareSeconds + Rules.RunSeconds))
    local open = Rules.clock(elapsed)
    if currentRound ~= cycle then
        currentRound = cycle
        for index, vault in ipairs(Rules.Vaults) do
            local egg = Rules.eggForRoll(vault, random:NextInteger(1, 100))
            roundEggs[index] = egg
            World.showEgg(map.vaults[index], egg)
        end
        for player, entry in pairs(entries) do
            entry.delivered = false
            local lost = entry.egg ~= nil
            clearEgg(player, entry)
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
    if not open then
        for player in pairs(entries) do
            local humanoid, root = characterParts(player)
            if root and humanoid and humanoid.Health > 0 and root.Position.X > Rules.GateX then
                player.Character:PivotTo(map.spawn.CFrame + Vector3.new(0, 4, 0))
                root.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end
    return open
end

for index, display in ipairs(map.vaults) do
    local vault = Rules.Vaults[index]
    withNearbyPlayer(display.prompt, function(player, entry, root)
        local open = syncRound()
        if not Rules.canCollect(entry.tier, vault, entry.egg ~= nil, open, entry.delivered) then
            if open and entry.tier < vault.tier then
                publish(player, entry, "Для этого яйца нужен уровень скорости " .. vault.tier .. ".")
            end
            return
        end
        local egg = roundEggs[index]
        entry.egg = egg
        advanceOnboarding(player, entry, Rules.onboardingAfterPickup(entry.onboarding))
        entry.eggVault = vault
        entry.eggVisual = accessory(root, "EggstrideEgg", World.variantColor(egg),
            Vector3.new(2.15, 2.7, 2.15), Vector3.new(0, 0.65, -1.8))
        applySpeed(player, entry)
        publish(player, entry, if egg.ability == "Лиана"
            then "Лиана может открыть путь домой. Ищи росток у края острова."
            else "Возвращайся в лагерь и подойди к инкубатору.")
    end)
end

withNearbyPlayer(map.vinePrompt, function(player, entry)
    if not syncRound() or not entry.egg or entry.egg.ability ~= "Лиана" or entry.abilityUsed then
        return
    end
    if vineEndsAt then
        publish(player, entry, "Мост уже открыт. Можно бежать!")
        return
    end
    entry.abilityUsed = true
    vineEndsAt = workspace:GetServerTimeNow() + Rules.VineDuration
    World.showVine(map.vine, true)
    publish(player, entry, "Мост из лиан открыт на " .. Rules.VineDuration .. " сек.")
end)

withNearbyPlayer(map.hatch, function(player, entry, root)
    if not syncRound() or not entry.egg then
        return
    end
    local egg = entry.egg
    local vault = entry.eggVault
    clearEgg(player, entry)
    entry.delivered = true
    entry.coins += vault.coins
    local pet = Rules.hatchForRoll(vault, egg, random:NextInteger(1, 100))
    local isNew = entry.ownedPets[pet.id] == nil
    if isNew then
        entry.ownedPets[pet.id] = pet
        player:SetAttribute("OwnsPet_" .. pet.id, true)
    end
    if not entry.pet then
        entry.pet = pet
        showPet(root, pet)
    end
    advanceOnboarding(player, entry, 3)
    local result = if isNew then "Новый в журнале: " else "Вылупился "
    publish(player, entry, result .. pet.name .. " · " .. pet.rarity .. " · +" .. vault.coins .. " монет.")
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
        showPet(root, pet)
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
