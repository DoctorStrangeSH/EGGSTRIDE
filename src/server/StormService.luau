-- Sky storm: darkens the sky, spawns one golden egg above an island for the whole
-- server and pays out a mythic pet to whoever carries it to their base.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Eggstride")
local Storm = require(Shared.Storm)
local Rules = require(Shared.Rules)

local StormService = {}

local GOLD = Color3.fromRGB(255, 205, 70)

local function part(parent, name, size, cframe, color)
    local prop = Instance.new("Part")
    prop.Name = name
    prop.Size = size
    prop.CFrame = cframe
    prop.Color = color
    prop.Material = Enum.Material.Neon
    prop.Anchored = true
    prop.CanCollide = false
    prop.CanTouch = false
    prop.CanQuery = false
    prop.CastShadow = false
    prop.Parent = parent
    return prop
end

local function weldTo(root, prop, offset)
    prop.Anchored = false
    prop.Massless = true
    prop.CFrame = root.CFrame * offset
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = prop
    weld.Parent = prop
    prop.Parent = root
end

-- deps: entries, catalog, publish, translate, characterParts, applySpeed, startedAt,
-- bases, hatchPosition, expired
function StormService.new(deps)
    local self = {}
    local entries = deps.entries
    local random = Random.new()
    local folder = Instance.new("Folder")
    folder.Name = "EggstrideStorm"
    folder.Parent = workspace

    local calm = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        OutdoorAmbient = Lighting.OutdoorAmbient,
    }
    local dark = {
        Brightness = 0.9,
        ClockTime = 18.6,
        OutdoorAmbient = Color3.fromRGB(80, 78, 120),
    }

    local state -- nil, "next", "warning", "active", "done"
    local forced = {} -- cycle -> name of the player who bought the storm
    local currentCycle = 0
    local spot
    local egg, eggPrompt, updraft
    local carrier

    local function setShared()
        Shared:SetAttribute("StormState", state)
        Shared:SetAttribute("StormSpot", spot and spot.label or nil)
        Shared:SetAttribute("StormCarrier", carrier and carrier.DisplayName or nil)
        local summoner = forced[currentCycle] or (state == "next" and forced[currentCycle + 1]) or nil
        Shared:SetAttribute("StormSummoner", summoner)
    end

    local function removeWorld()
        for _, item in ipairs({ egg, updraft }) do
            if item then
                item:Destroy()
            end
        end
        egg, eggPrompt, updraft = nil, nil, nil
    end

    local function clearCarrier(message)
        local player = carrier
        if not player then
            return
        end
        carrier = nil
        local entry = entries[player]
        if entry then
            entry.golden = nil
            for _, field in ipairs({ "goldenVisual", "goldenBeacon", "goldenPrompt", "goldenHighlight" }) do
                if entry[field] then
                    entry[field]:Destroy()
                    entry[field] = nil
                end
            end
            player:SetAttribute("CarryingGolden", nil)
            deps.applySpeed(player, entry)
            if message then
                deps.publish(player, entry, message)
            end
        end
        setShared()
    end

    local grab

    local function placeEgg()
        removeWorld()
        if state ~= "active" or not spot then
            return
        end
        local position = Vector3.new(spot.x, Storm.EggHeight, spot.z)
        egg = part(folder, "Золотое яйцо", Vector3.new(3.2, 4, 3.2), CFrame.new(position), GOLD)
        egg.Shape = Enum.PartType.Ball
        local light = Instance.new("PointLight")
        light.Range = 30
        light.Brightness = 3
        light.Color = GOLD
        light.Parent = egg
        local ray = part(folder, "Луч золотого яйца", Vector3.new(1, 120, 1), CFrame.new(position + Vector3.new(0, 62, 0)), GOLD)
        ray.Transparency = 0.3
        ray.Parent = egg
        eggPrompt = Instance.new("ProximityPrompt")
        eggPrompt.ActionText = "Забрать золотое яйцо"
        eggPrompt.ObjectText = "Небесный шторм"
        eggPrompt.HoldDuration = 0.4
        eggPrompt.MaxActivationDistance = Storm.PromptDistance
        eggPrompt.RequiresLineOfSight = false
        eggPrompt:SetAttribute("SourceText", "Забрать золотое яйцо")
        CollectionService:AddTag(eggPrompt, "EggstrideWorldText")
        eggPrompt.Parent = egg
        eggPrompt.Triggered:Connect(function(player)
            grab(player, nil)
        end)
        if not spot.updraft then
            -- Temporary updraft from the island up to the egg.
            local height = Storm.UpdraftHeight + 8
            updraft = part(folder, "Штормовой поток",
                Vector3.new(height, Storm.UpdraftRadius * 2, Storm.UpdraftRadius * 2),
                CFrame.new(spot.x, Storm.UpdraftHeight - height / 2, spot.z) * CFrame.Angles(0, 0, math.pi / 2), GOLD)
            updraft.Shape = Enum.PartType.Cylinder
            updraft.Transparency = 0.85
            updraft:SetAttribute("Radius", Storm.UpdraftRadius)
            updraft:SetAttribute("Height", Storm.UpdraftHeight)
            CollectionService:AddTag(updraft, "EggstrideUpdraft")
        end
    end

    local function busy(entry)
        return entry.egg or entry.stolen or entry.golden or entry.weekly
    end

    -- Takes the golden egg from the sky (from == nil) or from another carrier.
    grab = function(player, from)
        local entry = entries[player]
        local humanoid, root = deps.characterParts(player)
        if state ~= "active" or not entry or deps.expired(entry.session) or busy(entry)
            or not humanoid or humanoid.Health <= 0 or not root then
            if entry and (entry.egg or entry.stolen) then
                deps.publish(player, entry, "Руки заняты: сначала донеси груз.")
            end
            return
        end
        if from then
            local _, fromRoot = deps.characterParts(from)
            if carrier ~= from or not fromRoot or (fromRoot.Position - root.Position).Magnitude > Storm.InterceptRadius + 2 then
                return
            end
            clearCarrier(nil)
            local fromEntry = entries[from]
            if fromEntry then
                deps.publish(from, fromEntry, "%s перехватил золотое яйцо!", player.DisplayName)
            end
        elseif not egg or (egg.Position - root.Position).Magnitude > Storm.PromptDistance + 2 then
            return
        end
        removeWorld()
        carrier = player
        entry.golden = true
        player:SetAttribute("CarryingGolden", true)

        local visual = part(folder, "Золотое яйцо", Vector3.new(2.4, 3, 2.4), CFrame.new(), GOLD)
        visual.Shape = Enum.PartType.Ball
        weldTo(root, visual, CFrame.new(0, 0.65, -1.9))
        entry.goldenVisual = visual
        local beacon = part(folder, "Луч золотого яйца", Vector3.new(1, 90, 1), CFrame.new(), GOLD)
        beacon.Transparency = 0.35
        weldTo(root, beacon, CFrame.new(0, 48, 0))
        entry.goldenBeacon = beacon
        local highlight = Instance.new("Highlight")
        highlight.FillColor = GOLD
        highlight.FillTransparency = 0.6
        highlight.Parent = player.Character
        entry.goldenHighlight = highlight

        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = "Intercept"
        prompt.ActionText = "Перехватить"
        prompt.HoldDuration = Storm.InterceptHoldSeconds
        prompt.MaxActivationDistance = Storm.InterceptRadius
        prompt.RequiresLineOfSight = false
        prompt:SetAttribute("CarrierUserId", player.UserId)
        prompt:SetAttribute("ObjectSource", "Золотое яйцо")
        CollectionService:AddTag(prompt, "EggstrideInterceptPrompt")
        prompt.Parent = root
        entry.goldenPrompt = prompt
        prompt.Triggered:Connect(function(interceptor)
            if interceptor ~= player then
                grab(interceptor, player)
            end
        end)

        deps.applySpeed(player, entry)
        deps.publish(player, entry, "Золотое яйцо у тебя! Неси его на свою базу.")
        setShared()
    end

    local function deliver(player, entry)
        local catalog = deps.catalog
        local pet = catalog[Storm.Pets[random:NextInteger(1, #Storm.Pets)]]
        clearCarrier(nil)
        state = "done"
        spot = nil
        setShared()
        entry.coins += Storm.Coins
        local isNew = not entry.ownedPets[pet.id]
        if isNew then
            entry.ownedPets[pet.id] = pet
            player:SetAttribute("OwnsPet_" .. pet.id, true)
        end
        local onBase = deps.bases.addPet(player, entry, pet)
        deps.publish(player, entry, if onBase then "Золотое яйцо: %s и %d монет!" else "Золотое яйцо: %s и %d монет! База заполнена.",
            deps.translate(player, pet.name), Storm.Coins)
        for other, otherEntry in pairs(entries) do
            if other ~= player then
                deps.publish(other, otherEntry, "%s донёс золотое яйцо!", player.DisplayName)
            end
        end
    end

    -- Paid storm: the next free round becomes a storm round.
    function self.summon(player, entry)
        local round = Storm.nextFreeRound(currentCycle, forced)
        forced[round] = player.DisplayName
        setShared()
        deps.publish(player, entry, "Шторм вызван! Он начнётся через %d раунд(а).", round - currentCycle)
        for other, otherEntry in pairs(entries) do
            if other ~= player then
                deps.publish(other, otherEntry, "%s вызвал небесный шторм!", player.DisplayName)
            end
        end
    end

    function self.drop(player, message)
        if carrier == player then
            clearCarrier(message)
            placeEgg()
            setShared()
        end
    end

    local function tweenSky(target)
        TweenService:Create(Lighting, TweenInfo.new(3), target):Play()
    end

    local function setState(newState)
        if newState == state or (state == "done" and newState == "active") then
            return
        end
        local wasActive = state == "active" or state == "done"
        state = newState
        if state == "active" then
            spot = Storm.spotForRoll(random:NextInteger(1, #Storm.Spots))
            tweenSky(dark)
            placeEgg()
        elseif wasActive then
            if carrier then
                clearCarrier("Шторм утих, золотое яйцо растаяло.")
            end
            spot = nil
            removeWorld()
            tweenSky(calm)
        end
        setShared()
    end

    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 0.2 then
            return
        end
        elapsed = 0
        local passed = workspace:GetServerTimeNow() - deps.startedAt
        local cycle = math.floor(passed / (Rules.PrepareSeconds + Rules.RunSeconds))
        local open = Rules.clock(passed)
        if cycle ~= currentCycle then
            forced[currentCycle] = nil
            currentCycle = cycle
        end
        local upcoming = Storm.state(cycle, open, forced)
        if state == "done" and upcoming == "active" then
            upcoming = "done"
        end
        setState(upcoming)

        local player = carrier
        if player then
            local entry = entries[player]
            local humanoid, root = deps.characterParts(player)
            if not entry or not humanoid or humanoid.Health <= 0 or not root then
                self.drop(player, nil)
                return
            end
            local center = deps.bases.plotCenter(entry)
            local target = center or deps.hatchPosition
            local offset = root.Position - target
            local radius = if center then 12 else 8
            if math.abs(offset.X) <= radius and math.abs(offset.Z) <= radius and math.abs(offset.Y) < 12 then
                deliver(player, entry)
            end
        end
    end)

    return self
end

return StormService
