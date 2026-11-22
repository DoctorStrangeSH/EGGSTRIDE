local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Eggstride")
local Rules = require(Shared.Rules)
local World = require(script.Parent.World)

local map = World.build(Rules)
local startedAt = workspace:GetServerTimeNow()
local round = Instance.new("Folder")
round.Name = "Round"
round:SetAttribute("StartedAt", startedAt)
round.Parent = Shared

local entries = {}

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
    player:SetAttribute("Coins", entry.coins)
    player:SetAttribute("SpeedTier", entry.tier)
    player:SetAttribute("BestPet", entry.best and Rules.Vaults[entry.best].pet or "")
    player:SetAttribute("EggName", entry.egg and Rules.Vaults[entry.egg].name or "")
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

local function showPet(root, index)
    local previous = root:FindFirstChild("EggstridePet")
    if previous then
        previous:Destroy()
    end
    local accent = World.VaultColors[index]
    local body = accessory(root, "EggstridePet", accent, Vector3.new(1.9, 1.45, 1.7), Vector3.new(2.6, 0, 2.4))
    for _, x in ipairs({ -0.43, 0.43 }) do
        accessory(body, "Eye", Color3.fromRGB(46, 40, 61), Vector3.new(0.21, 0.27, 0.21), Vector3.new(x, 0.1, -0.72))
        accessory(body, "Ear", accent, Vector3.new(0.44, 0.78, 0.47), Vector3.new(x * 1.55, 0.67, 0.05))
    end
end

local function clearEgg(player, entry)
    entry.egg = nil
    if entry.eggVisual then
        entry.eggVisual:Destroy()
        entry.eggVisual = nil
    end
    applySpeed(player, entry)
end

local function join(player)
    if entries[player] then
        return
    end
    local entry = { coins = Rules.StartCoins, tier = 1, delivered = false }
    entries[player] = entry
    publish(player, entry, "Заработай скорость в лагере или сразу попробуй ближайший остров.")
    player.RespawnLocation = map.spawn

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
        if entry.best then
            showPet(root, entry.best)
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
        if not entry or not humanoid or humanoid.Health <= 0 or not root then
            return
        end
        if (root.Position - prompt.Parent.Position).Magnitude > prompt.MaxActivationDistance then
            return
        end
        action(player, entry, root)
    end)
end

local wasOpen = false
local currentRound = 0

local function syncRound()
    local elapsed = workspace:GetServerTimeNow() - startedAt
    local cycle = math.floor(elapsed / (Rules.PrepareSeconds + Rules.RunSeconds))
    local open = Rules.clock(elapsed)
    if currentRound ~= cycle then
        currentRound = cycle
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

for index, prompt in ipairs(map.vaults) do
    local vault = Rules.Vaults[index]
    withNearbyPlayer(prompt, function(player, entry, root)
        local open = syncRound()
        if not Rules.canCollect(entry.tier, vault, entry.egg ~= nil, open, entry.delivered) then
            if open and entry.tier < vault.tier then
                publish(player, entry, "Для этого яйца нужен уровень скорости " .. vault.tier .. ".")
            end
            return
        end
        entry.egg = index
        entry.eggVisual = accessory(root, "EggstrideEgg", World.VaultColors[index],
            Vector3.new(2.15, 2.7, 2.15), Vector3.new(0, 0.65, -1.8))
        applySpeed(player, entry)
        publish(player, entry, "Возвращайся в лагерь и подойди к инкубатору.")
    end)
end

withNearbyPlayer(map.hatch, function(player, entry, root)
    if not syncRound() or not entry.egg then
        return
    end
    local index = entry.egg
    local vault = Rules.Vaults[index]
    clearEgg(player, entry)
    entry.delivered = true
    entry.coins += vault.coins
    if not entry.best or index > entry.best then
        entry.best = index
        showPet(root, index)
    end
    publish(player, entry, "Вылупился " .. vault.pet .. " · +" .. vault.coins .. " монет.")
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

Players.PlayerAdded:Connect(join)
Players.PlayerRemoving:Connect(function(player)
    entries[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do
    join(player)
end

while true do
    syncRound()
    task.wait(0.15)
end
