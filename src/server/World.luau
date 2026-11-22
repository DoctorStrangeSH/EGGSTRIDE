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

local function sign(anchor, title, subtitle)
    local plate = Instance.new("BillboardGui")
    plate.Size = UDim2.fromScale(13, 4)
    plate.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
    plate.MaxDistance = 55
    plate.LightInfluence = 0
    plate.AlwaysOnTop = true
    plate.Parent = anchor

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundColor3 = Colors.plum
    label.BackgroundTransparency = 0.07
    label.TextColor3 = Colors.cream
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Text = title .. "\n" .. subtitle
    label.Parent = plate
    Instance.new("UICorner", label).CornerRadius = UDim.new(0.2, 0)
    Instance.new("UIPadding", label).PaddingBottom = UDim.new(0.1, 0)
    return label
end

local function prompt(anchor, action, object)
    local interaction = Instance.new("ProximityPrompt")
    interaction.ActionText = action
    interaction.ObjectText = object
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

local function runway(parent, fromX, toX, lane)
    local center = (fromX + toX) / 2
    part(parent, "Мост", Vector3.new(toX - fromX, 1, 13), Vector3.new(center, -0.5, lane), Colors.wood, true)
    for _, z in ipairs({ -6, 6 }) do
        part(parent, "Бортик", Vector3.new(toX - fromX, 0.6, 0.5), Vector3.new(center, 0.3, lane + z), Colors.cream, false)
    end
end

local function buildWindTrail(parent, fromX, toX, anchorAbility)
    local lane = 7
    local width = 8
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
    for _, x in ipairs({ fromX, toX }) do
        local marker = part(parent, "Флюгер", Vector3.new(0.6, 3, 0.6), Vector3.new(x, 1.5, lane + 3.5), Colors.azure, false)
        table.insert(signs, sign(marker, "ВЕТРОВАЯ ТРОПА", "Штиль"))
        local bridgeMarker = part(parent, "Указатель моста", Vector3.new(0.6, 3, 0.6),
            Vector3.new(x, 1.5, -8), Colors.wood, false)
        sign(bridgeMarker, "ОБЫЧНЫЙ МОСТ", "Постоянная скорость")
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

    local anchor = part(parent, "Стойка якоря", Vector3.new(1.5, 2, 1.5), Vector3.new(toX + 3, 1, lane - 3),
        Colors.amber, false)
    sign(anchor, anchorAbility.name, string.format(anchorAbility.effect, anchorAbility.duration))
    local anchorPrompt = prompt(anchor, "Активировать", anchorAbility.name)
    anchorPrompt.MaxActivationDistance = 7

    local lever = part(parent, "Рычаг ветра", Vector3.new(1.5, 2.4, 1.5),
        Vector3.new(fromX - 4, 1.2, lane - 4), Colors.lilac, false)
    local leverLabel = sign(lever, "РЫЧАГ ВЕТРА", "Помоги игроку с яйцом")
    local leverPrompt = prompt(lever, "Развернуть ветер", "Рычаг ветра")
    leverPrompt.MaxActivationDistance = 7

    return {
        part = trail, signs = signs, arrows = arrows, anchorPrompt = anchorPrompt,
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
    if overrideActive then
        description ..= " · рычаг"
    end
    local leverState = if overrideActive then "Ветер развёрнут"
        elseif used then "До следующего раунда"
        elseif direction == 0 then "Штиль"
        elseif direction < 0 then "Ветер уже помогает вернуться"
        else "Помоги игроку с яйцом"
    trail.leverLabel.Text = "РЫЧАГ ВЕТРА\n" .. leverState
    for _, label in ipairs(trail.signs) do
        label.Text = "ВЕТРОВАЯ ТРОПА\n" .. description
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

local function buildStormRelay(parent, originX, landingX, ability, trial)
    local origin = part(parent, "Грозовой маяк", Vector3.new(2, 4, 2),
        Vector3.new(originX, 2, 8), Colors.lilac, false)
    origin.Material = Enum.Material.Neon
    local label = sign(origin, ability.name, ability.effect .. "\n"
        .. trial.name .. " · доставь яйцо при " .. trial.secondsLeft .. "+ сек.")
    label.Parent.Size = UDim2.fromScale(19, 6)
    local launch = prompt(origin, "Перенестись", ability.name)
    launch.MaxActivationDistance = 7

    local landing = part(parent, "Приёмный маяк", Vector3.new(7, 0.3, 7),
        Vector3.new(landingX, 0.16, 8), Colors.lilac, false)
    landing.Material = Enum.Material.Neon
    sign(landing, "ПРИЁМНЫЙ МАЯК", "С Грозового острова")
    local destination = landing.Position + Vector3.new(0, 4, 0)
    local pulse = part(parent, "Грозовой импульс", Vector3.new(0.55, 0.55, (origin.Position - destination).Magnitude),
        (origin.Position + destination) * 0.5, Colors.lilac, false)
    pulse.CFrame = CFrame.lookAt(pulse.Position, destination)
    pulse.Material = Enum.Material.Neon
    pulse.CanQuery = false
    pulse.Transparency = 1
    return {
        prompt = launch,
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
        { id = "Finish", x = -108, z = 0, title = "СТАРТ И ФИНИШ" },
        { id = "First", x = -138, z = -13, title = "МЕТКА 1" },
        { id = "Second", x = -167, z = 13, title = "МЕТКА 2" },
        { id = "Egg", x = -206, z = 0, title = "ТРЕНИРОВОЧНОЕ ЯЙЦО" },
    }) do
        local plate = part(parent, marker.id, Vector3.new(7, 0.16, 7), Vector3.new(marker.x, 0.08, marker.z),
            if marker.id == "Egg" then Colors.cream else Colors.azure, false)
        plate.Material = Enum.Material.Neon
        points[marker.id] = plate
        sign(plate, marker.title, if marker.id == "Egg" then "Вернись через обе метки" else "Забег недели")
    end

    local entrance = part(parent, "Вход на трассу недели", Vector3.new(4, 0.3, 4),
        Vector3.new(-15, 0.2, -8), Colors.lilac, false)
    sign(entrance, "ЗАБЕГ НЕДЕЛИ", "Одинаковая скорость")
    return {
        prompt = prompt(entrance, "Начать забег", "Забег недели"),
        points = points,
    }
end

function World.variantColor(egg)
    return Color3.fromRGB(table.unpack(egg.color))
end

function World.showEgg(display, egg, rules)
    display.part.Color = World.variantColor(egg)
    local definition = rules.Abilities[egg.ability]
    local ability = if definition then definition.name .. " · " .. rules.abilityEffect(definition)
        else "Без способности"
    display.label.Text = egg.name
        .. "\n" .. egg.rarity .. " · Скорость " .. display.tier
        .. "\n" .. ability
        .. "\nРедкий питомец " .. display.rareChance[egg.rarity] .. "%"
    display.prompt.ObjectText = egg.name
end

function World.showVine(vine, active)
    vine.CanCollide = active
    vine.Transparency = if active then 0 else 1
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

    local hatch = part(scene, "Инкубатор", Vector3.new(8, 0.4, 8), Vector3.new(14, 0.2, 0), Colors.cream, true)
    local shop = part(scene, "Тренировка", Vector3.new(7, 0.4, 7), Vector3.new(-6, 0.2, 11), Colors.azure, true)
    sign(hatch, "ИНКУБАТОР", "Сдай яйцо")
    sign(shop, "ТРЕНИРОВКА", "Увеличь скорость")

    runway(scene, 24, 50, -9)
    local vine = part(scene, "Мост из лиан", Vector3.new(26, 0.8, 8), Vector3.new(37, -0.4, 8), Colors.grass, false)
    World.showVine(vine, false)
    local sprout = part(scene, "Росток", Vector3.new(2, 1.5, 2), Vector3.new(52, 0.75, 8), Colors.grass, false)
    sign(sprout, "ЛИАНА", "Выращивает мост в лагерь")
    local vinePrompt = prompt(sprout, "Вырастить мост", "Лиана")
    vinePrompt.MaxActivationDistance = 8
    local gate = part(scene, "Ворота", Vector3.new(1, 10, 32), Vector3.new(rules.GateX, 5, 0), Colors.lilac, true)
    gate.Material = Enum.Material.Neon
    gate.Transparency = 0.35

    local vaultDisplays = {}
    local previousX
    local windTrail
    local stormRelay
    for index, vault in ipairs(rules.Vaults) do
        local accent = World.VaultColors[index]
        if index == 2 then
            windTrail = buildWindTrail(scene, previousX + 12, vault.x - 12, rules.Abilities.anchor)
        elseif previousX then
            runway(scene, previousX + 13, vault.x - 13, 0)
            if index == 3 then
                stormRelay = buildStormRelay(scene, vault.x - 10, previousX + 8, rules.Abilities.relay, rules.StormTrial)
            end
        end
        island(scene, vault.x, 28, 30, Colors.grass:Lerp(accent, 0.6))
        local treeName = if index == 1 then "RoundTree" else "Pine"
        for _, z in ipairs({ -11, 11 }) do
            vegetation(scene, treeName, vault.x + 8, z, Vector3.new(7, 11 + index, 7), z * index)
            vegetation(scene, "Rock", vault.x - 7, z, Vector3.new(4, 2.5, 3.5), z)
        end
        part(scene, "Пьедестал", Vector3.new(5, 1, 5), Vector3.new(vault.x, 0.5, 0), Colors.plum, false)
        local egg = part(scene, "Яйцо", Vector3.new(2.4, 3.2, 2.4), Vector3.new(vault.x, 2.6, 0), accent, false)
        egg.Shape = Enum.PartType.Ball
        local eggLabel = sign(egg, vault.name, "Скорость " .. vault.tier)
        eggLabel.Parent.Size = UDim2.fromScale(17, 7)
        eggLabel.Parent.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
        vaultDisplays[index] = {
            part = egg,
            label = eggLabel,
            prompt = prompt(egg, "Забрать яйцо", vault.name),
            tier = vault.tier,
            rareChance = rules.RarePetChance,
        }
        previousX = vault.x
    end

    local random = Random.new(73)
    for i = 1, 30 do
        local cloud = part(scene, "Облако", Vector3.new(20, 5, 10),
            Vector3.new(random:NextNumber(-45, 285), random:NextNumber(-27, -10), random:NextNumber(31, 61) * (if i % 2 == 0 then 1 else -1)),
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
        vinePrompt = vinePrompt,
        hatch = prompt(hatch, "Вылупить", "Инкубатор"),
        shop = prompt(shop, "Тренироваться", "Скорость"),
        vaults = vaultDisplays,
    }
end

return World
