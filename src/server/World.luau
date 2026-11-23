local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

local World = {}
local Colors = {
    grass = Color3.fromRGB(113, 213, 129),
    rock = Color3.fromRGB(91, 103, 143),
    wood = Color3.fromRGB(212, 155, 93),
    cream = Color3.fromRGB(255, 223, 155),
    plum = Color3.fromRGB(40, 37, 73),
    azure = Color3.fromRGB(123, 208, 250),
    amber = Color3.fromRGB(255, 178, 76),
    lilac = Color3.fromRGB(182, 150, 255),
}
World.VaultColors = { Colors.cream, Colors.amber, Colors.lilac }

local function part(parent, name, size, position, color, collision)
    local prop = Instance.new("Part")
    prop.Name = name
    prop.Size = size
    prop.Position = position
    prop.Color = color
    prop.Material = Enum.Material.SmoothPlastic
    prop.Anchored = true
    prop.CanCollide = collision
    prop.CanTouch = false
    prop.TopSurface = Enum.SurfaceType.Smooth
    prop.BottomSurface = Enum.SurfaceType.Smooth
    prop.Parent = parent
    return prop
end

local function sign(anchor, text)
    local plate = Instance.new("BillboardGui")
    plate.Name = "LocalSign"
    plate.Size = UDim2.fromOffset(126, 30)
    plate.StudsOffsetWorldSpace = Vector3.new(0, anchor.Size.Y / 2 + 1.5, 0)
    plate.MaxDistance = 30
    plate.LightInfluence = 0
    plate.AlwaysOnTop = false
    plate.Parent = anchor

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundColor3 = Colors.plum
    label.BackgroundTransparency = 0.18
    label.TextColor3 = Colors.cream
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextWrapped = true
    label.Text = text
    label.AutoLocalize = false
    label:SetAttribute("SourceText", text)
    CollectionService:AddTag(label, "EggstrideWorldText")
    label.Parent = plate
    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 6)
    local padding = Instance.new("UIPadding", label)
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    return label
end

local function prompt(anchor, action, name)
    local interaction = Instance.new("ProximityPrompt")
    interaction.Name = name or "ProximityPrompt"
    interaction.ActionText = action
    interaction.AutoLocalize = false
    interaction:SetAttribute("SourceText", action)
    CollectionService:AddTag(interaction, "EggstrideWorldText")
    interaction.MaxActivationDistance = 12
    interaction.RequiresLineOfSight = false
    interaction.Parent = anchor
    return interaction
end

local function island(parent, x, width, depth, turf)
    part(parent, "Основание", Vector3.new(width - 4, 8, depth - 4), Vector3.new(x, -6, 0), Colors.rock, false)
    part(parent, "Трава", Vector3.new(width, 2, depth), Vector3.new(x, -1, 0), turf, true)
end

local function vegetation(parent, name, x, z, size, angle)
    local mesh = ServerStorage.Nature[name]:Clone()
    mesh.Anchored = true
    mesh.CanCollide = false
    mesh.CanTouch = false
    mesh.CanQuery = false
    mesh.Size = size
    mesh.CFrame = CFrame.new(x, size.Y / 2, z) * CFrame.Angles(0, angle, 0)
    mesh.Parent = parent
end

local function runway(parent, fromX, toX, lane, exposed)
    local center = (fromX + toX) / 2
    part(parent, "Мост", Vector3.new(toX - fromX, 1, if exposed then 9 else 18),
        Vector3.new(center, -0.5, lane), if exposed then Colors.lilac else Colors.wood, true)
    if exposed then
        return
    end
    for _, z in ipairs({ -8.75, 8.75 }) do
        part(parent, "Бортик", Vector3.new(toX - fromX, 1.6, 0.5), Vector3.new(center, 0.8, lane + z), Colors.cream, true)
    end
end

local function buildWindTrail(parent, fromX, toX)
    local lane = 9
    local width = 14
    local trail = part(parent, "Ветровая тропа", Vector3.new(toX - fromX, 1, width),
        Vector3.new((fromX + toX) / 2, -0.5, lane), Colors.azure, true)

    local arrows = {}
    for _, t in ipairs({ 0.15, 0.50, 0.85 }) do
        local origin = Vector3.new(fromX + (toX - fromX) * t, 0.05, lane)
        local wings = {}
        for _, side in ipairs({ -1, 1 }) do
            local wing = part(parent, "Стрелка ветра", Vector3.new(2.2, 0.1, 0.24), origin, Colors.cream, false)
            wing.CanQuery = false
            table.insert(wings, { part = wing, side = side })
        end
        table.insert(arrows, { origin = origin, wings = wings })
    end
    local signs = {}
    local markers = {}
    for _, x in ipairs({ fromX, toX }) do
        local marker = part(parent, "Флюгер", Vector3.new(0.6, 3, 0.6), Vector3.new(x, 1.5, lane + 3.5), Colors.azure, false)
        table.insert(markers, marker)
        table.insert(signs, sign(marker, "Ветровая тропа\nШтиль"))
        local bridgeMarker = part(parent, "Указатель моста", Vector3.new(0.6, 3, 0.6),
            Vector3.new(x, 1.5, -8), Colors.wood, false)
        sign(bridgeMarker, "Обходной мост")
    end

    local bends = {
        Vector3.new(fromX, -0.5, -8),
        Vector3.new(fromX + 12, -0.5, -21),
        Vector3.new(toX - 12, -0.5, -21),
        Vector3.new(toX, -0.5, -8),
    }
    for index = 1, #bends - 1 do
        local a, b = bends[index], bends[index + 1]
        local midpoint = a:Lerp(b, 0.5)
        local bridge = part(parent, "Пролёт обычного моста", Vector3.new(13, 1, (b - a).Magnitude + 2),
            midpoint, Colors.wood, true)
        bridge.CFrame = CFrame.lookAt(midpoint, b)
    end

    local lever = part(parent, "Рычаг ветра", Vector3.new(1.5, 2.4, 1.5),
        Vector3.new(fromX - 4, 1.2, lane - 4), Colors.lilac, false)
    local leverLabel = sign(lever, "Рычаг ветра")
    local leverPrompt = prompt(lever, "Развернуть ветер")
    leverPrompt.MaxActivationDistance = 7

    return {
        part = trail, signs = signs, arrows = arrows,
        meadowMarker = markers[1], amberMarker = markers[2],
        leverLabel = leverLabel, leverPrompt = leverPrompt,
    }
end

function World.showWind(trail, direction, used, overrideActive)
    local description = "Штиль"
    if direction > 0 then
        description = "Ветер к Янтарному"
    elseif direction < 0 then
        description = "Ветер к Луговому"
    end
    local leverState = if overrideActive then "Ветер развёрнут"
        elseif used then "Уже использован"
        elseif direction == 0 then "Штиль"
        elseif direction < 0 then "Ветер к лагерю"
        else "Помоги с яйцом"
    trail.leverLabel:SetAttribute("SourceText", "Рычаг ветра\n" .. leverState)
    for _, label in ipairs(trail.signs) do
        label:SetAttribute("SourceText", "Ветровая тропа\n" .. description)
    end
    local rotation = if direction < 0 then math.pi else 0
    for _, arrow in ipairs(trail.arrows) do
        local base = CFrame.new(arrow.origin) * CFrame.Angles(0, rotation, 0)
        for _, wing in ipairs(arrow.wings) do
            wing.part.CFrame = base * CFrame.new(0, 0, wing.side * 0.6)
                * CFrame.Angles(0, wing.side * math.rad(35), 0)
            wing.part.Transparency = if direction == 0 then 1 else 0
        end
    end
end

local function buildStormRelay(parent, originX, landingX)
    local origin = part(parent, "Грозовой маяк", Vector3.new(8, 0.3, 8),
        Vector3.new(originX, 0.16, 8), Colors.lilac, false)
    origin.Material = Enum.Material.Neon
    sign(origin, "Разряд → Янтарный")

    local landing = part(parent, "Приёмный маяк", Vector3.new(7, 0.3, 7),
        Vector3.new(landingX, 0.16, 8), Colors.lilac, false)
    landing.Material = Enum.Material.Neon
    local destination = landing.Position + Vector3.new(0, 4, 0)
    local pulse = part(parent, "Грозовой импульс", Vector3.new(0.55, 0.55, (origin.Position - destination).Magnitude),
        (origin.Position + destination) * 0.5, Colors.lilac, false)
    pulse.CFrame = CFrame.lookAt(pulse.Position, destination)
    pulse.Material = Enum.Material.Neon
    pulse.CanQuery = false
    pulse.Transparency = 1
    return {
        origin = origin,
        destination = CFrame.lookAt(destination, destination + Vector3.new(-1, 0, 0)),
        pulse = pulse,
        flashes = 0,
    }
end

function World.flashRelay(relay)
    relay.flashes += 1
    local flash = relay.flashes
    relay.pulse.Transparency = 0.16
    task.delay(0.35, function()
        if flash == relay.flashes then
            relay.pulse.Transparency = 1
        end
    end)
end

local function buildWeekly(parent)
    local hall = part(parent, "Трасса недели", Vector3.new(122, 2, 36),
        Vector3.new(-160, -1, 0), Colors.rock, true)
    hall.Material = Enum.Material.SmoothPlastic
    for _, barrier in ipairs({ { x = -138, z = 5 }, { x = -167, z = -5 } }) do
        part(parent, "Барьер", Vector3.new(3, 10, 26), Vector3.new(barrier.x, 5, barrier.z), Colors.plum, true)
    end

    local points = {}
    for _, marker in ipairs({
        { id = "Finish", x = -108, z = 0 },
        { id = "First", x = -138, z = -13 },
        { id = "Second", x = -167, z = 13 },
        { id = "Egg", x = -206, z = 0 },
    }) do
        local plate = part(parent, marker.id, Vector3.new(7, 0.16, 7), Vector3.new(marker.x, 0.08, marker.z),
            if marker.id == "Egg" then Colors.cream else Colors.azure, false)
        plate.Material = Enum.Material.Neon
        points[marker.id] = plate
    end

    local entrance = part(parent, "Вход на трассу недели", Vector3.new(4, 0.3, 4),
        Vector3.new(-15, 0.2, -8), Colors.lilac, false)
    sign(entrance, "Забег недели")
    return {
        prompt = prompt(entrance, "Начать забег"),
        points = points,
    }
end

function World.showPrize(prize, available)
    prize.part.Transparency = if available then 0 else 1
    prize.label.Parent.Enabled = available
    prize.prompt.Enabled = available
end

function World.showVine(vine, active)
    vine.CanCollide = active
    vine.Transparency = if active then 0 else 1
end

local function buildCampDecor(scene, palette)
    local decor = Instance.new("Folder")
    decor.Name = "CampDecor"
    decor.Parent = scene

    local function prop(name, role, size, position)
        local piece = part(decor, name, size, position, Color3.fromRGB(table.unpack(palette[role])), false)
        piece.CanQuery = false
        CollectionService:AddTag(piece, "EggstrideCamp_" .. role)
        return piece
    end

    for _, z in ipairs({ -15, 15 }) do
        for _, x in ipairs({ -10, 10 }) do
            prop("Основание фонаря", "last", Vector3.new(2, 0.25, 2), Vector3.new(x, 0.13, z))
            prop("Столб фонаря", "first", Vector3.new(0.32, 4.4, 0.32), Vector3.new(x, 2.2, z))
            local lantern = prop("Светильник", "glow", Vector3.new(0.84, 1.28, 0.84), Vector3.new(x, 4.7, z))
            lantern.Material = Enum.Material.Neon
            prop("Крыша фонаря", "first", Vector3.new(1.16, 0.22, 1.16), Vector3.new(x, 5.42, z))
        end
    end

    for _, z in ipairs({ -6.6, 6.6 }) do
        local x = 20
        prop("Стойка флага", "first", Vector3.new(0.28, 6.6, 0.28), Vector3.new(x, 3.3, z))
        prop("Перекладина", "first", Vector3.new(0.32, 0.28, 2.9), Vector3.new(x, 6.35, z))
        prop("Флаг лагеря", "last", Vector3.new(0.12, 2.65, 2.4), Vector3.new(x, 4.92, z))
        prop("Полоса флага", "glow", Vector3.new(0.14, 0.20, 2.42), Vector3.new(x, 3.72, z))
    end

    for _, z in ipairs({ -3.1, 3.1 }) do
        prop("Край дорожки", "last", Vector3.new(17, 0.07, 0.18), Vector3.new(4.5, 0.037, z))
    end
end

function World.build(rules)
    Lighting.ClockTime = 14
    Lighting.Brightness = 2.4
    Lighting.Ambient = Color3.fromRGB(144, 153, 174)
    Lighting.OutdoorAmbient = Color3.fromRGB(175, 182, 201)

    local scene = Instance.new("Folder")
    scene.Name = "EggstrideWorld"
    scene.Parent = workspace

    local atmosphere = Instance.new("Atmosphere")
    atmosphere.Density = 0.18
    atmosphere.Color = Color3.fromRGB(204, 232, 255)
    atmosphere.Parent = Lighting

    island(scene, 0, 50, 52, Colors.grass)
    buildCampDecor(scene, rules.CampPalette)
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "Camp"
    spawn.Position = Vector3.new(0, 0.1, 0)
    spawn.Size = Vector3.new(8, 0.2, 8)
    spawn.Anchored = true
    spawn.Transparency = 1
    spawn.CanCollide = false
    spawn.Neutral = true
    spawn.Duration = 0
    spawn.Parent = scene

    for _, z in ipairs({ -13, 13 }) do
        vegetation(scene, "RoundTree", -17, z, Vector3.new(10, 13, 10), z)
        vegetation(scene, "Pine", 19, z * 1.4, Vector3.new(8, 14, 8), -z)
        vegetation(scene, "Rock", 7, z * 1.5, Vector3.new(6, 3, 4), z)
    end

    local hatch = part(scene, "Инкубатор", Vector3.new(8, 0.4, 8), Vector3.new(rules.HatchX, 0.2, 0), Colors.cream, true)
    local shop = part(scene, "Тренировка", Vector3.new(7, 0.4, 7), Vector3.new(0, 0.2, 10), Colors.azure, true)
    sign(hatch, "Инкубатор")
    sign(shop, "Прокачка скорости")

    local meadowEdge = rules.Vaults[1].x - 20
    runway(scene, 24, meadowEdge, -7)
    local vine = part(scene, "Мост из лиан", Vector3.new(meadowEdge - 24, 0.8, 14),
        Vector3.new((meadowEdge + 24) / 2, -0.4, 10), Colors.grass, false)
    World.showVine(vine, false)
    local sprout = part(scene, "Росток", Vector3.new(5, 0.35, 5),
        Vector3.new(meadowEdge + 2, 0.18, 10), Colors.grass, false)
    sprout.Material = Enum.Material.Neon
    sign(sprout, "Лиана → Лагерь")
    local gate = part(scene, "Ворота", Vector3.new(1, 10, 42), Vector3.new(rules.GateX, 5, 0), Colors.lilac, true)
    gate.Material = Enum.Material.Neon
    gate.Transparency = 0.35

    local vaultDisplays = {}
    local previousX
    local windTrail
    local stormRelay
    for index, vault in ipairs(rules.Vaults) do
        local accent = World.VaultColors[index]
        if index == 2 then
            windTrail = buildWindTrail(scene, previousX + 19, vault.x - 19)
        elseif previousX then
            local fromX, toX = previousX + 19, vault.x - 19
            runway(scene, fromX, toX, -17)
            runway(scene, fromX, toX, 12, true)
            for _, x in ipairs({ fromX, toX }) do
                local safe = part(scene, "Указатель широкого моста", Vector3.new(0.6, 2, 0.6),
                    Vector3.new(x, 1, -22), Colors.wood, false)
                local quick = part(scene, "Указатель грозовой тропы", Vector3.new(0.6, 2, 0.6),
                    Vector3.new(x, 1, 16), Colors.lilac, false)
                sign(safe, "Широкий мост")
                sign(quick, "Короткая тропа")
            end
            stormRelay = buildStormRelay(scene, vault.x - 10, previousX + 8)
        end
        island(scene, vault.x, 40, 54, Colors.grass:Lerp(accent, 0.6))
        local treeName = if index == 1 then "RoundTree" else "Pine"
        for _, z in ipairs({ -11, 11 }) do
            vegetation(scene, treeName, vault.x + 8, z, Vector3.new(7, 11 + index, 7), z * index)
            vegetation(scene, "Rock", vault.x - 7, z, Vector3.new(4, 2.5, 3.5), z)
        end
        part(scene, "Пьедестал", Vector3.new(5, 1, 5), Vector3.new(vault.x, 0.5, 0), Colors.plum, false)
        local egg = part(scene, "Яйцо", Vector3.new(2.4, 3.2, 2.4), Vector3.new(vault.x, 2.6, 0), accent, false)
        egg.Shape = Enum.PartType.Ball
        sign(egg, "Яйцо · " .. vault.name)
        vaultDisplays[index] = {
            part = egg,
            prompt = prompt(egg, "Забрать яйцо"),
        }
        previousX = vault.x
    end

    local prizes = {}
    for _, definition in ipairs(rules.Prizes) do
        local vault = rules.Vaults[definition.vaultIndex]
        local x, z = vault.x + 5, if definition.id == "amber" then -18 else 18
        local accent = World.VaultColors[definition.vaultIndex]
        local pedestal = part(scene, definition.name, Vector3.new(6, 1, 6),
            Vector3.new(x, 0.5, z), accent, false)
        pedestal.Material = Enum.Material.Neon
        local egg = part(scene, definition.name, Vector3.new(2.4, 3.2, 2.4),
            Vector3.new(x, 2.6, z), accent, false)
        egg.Shape = Enum.PartType.Ball
        local display = {
            part = egg,
            label = sign(egg, if definition.id == "storm" then definition.name else "Призовое яйцо"),
            prompt = prompt(egg, if definition.id == "storm" then "Забрать реликвию" else "Забрать призовое яйцо"),
        }
        prizes[definition.id] = display
        World.showPrize(display, false)
    end

    local random = Random.new(73)
    for i = 1, 30 do
        local cloud = part(scene, "Облако", Vector3.new(20, 5, 10),
            Vector3.new(random:NextNumber(-45, 400), random:NextNumber(-27, -10), random:NextNumber(31, 61) * (if i % 2 == 0 then 1 else -1)),
            Color3.fromRGB(239, 247, 255), false)
        cloud.Shape = Enum.PartType.Ball
    end

    return {
        spawn = spawn,
        weekly = buildWeekly(scene),
        gate = gate,
        windTrail = windTrail,
        stormRelay = stormRelay,
        vine = vine,
        sprout = sprout,
        prizes = prizes,
        hatch = hatch,
        shop = prompt(shop, "Купить скорость", "SpeedUpgrade"),
        vaults = vaultDisplays,
    }
end

return World
