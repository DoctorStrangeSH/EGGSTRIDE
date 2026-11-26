-- Builds the base district south of the camp: one island, a bridge and eight plots.
-- Owner names, timers and income are drawn by the client from plot attributes.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bases = require(ReplicatedStorage:WaitForChild("Eggstride"):WaitForChild("Bases"))

local BaseWorld = {}

local Colors = {
    grass = Color3.fromRGB(113, 213, 129),
    rock = Color3.fromRGB(91, 103, 143),
    wood = Color3.fromRGB(212, 155, 93),
    cream = Color3.fromRGB(255, 223, 155),
    plum = Color3.fromRGB(40, 37, 73),
    gold = Color3.fromRGB(255, 205, 86),
    shield = Color3.fromRGB(120, 200, 255),
}
local PlotColors = {
    Color3.fromRGB(255, 140, 140), Color3.fromRGB(255, 190, 110), Color3.fromRGB(250, 235, 120),
    Color3.fromRGB(150, 230, 140), Color3.fromRGB(120, 220, 230), Color3.fromRGB(130, 160, 255),
    Color3.fromRGB(200, 150, 255), Color3.fromRGB(255, 150, 220),
}

BaseWorld.PlotSize = 24
local DISTRICT_X, DISTRICT_Z = -38, -98
local ROW_Z = { -82, -114 }
local COLUMN_X = { -82, -56, -30, -4 }

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

local function prompt(anchor, action, name, hold)
    local proximity = Instance.new("ProximityPrompt")
    proximity.Name = name
    proximity.ActionText = action
    proximity.HoldDuration = hold or 0
    proximity.MaxActivationDistance = 9
    proximity.RequiresLineOfSight = false
    proximity.Parent = anchor
    return proximity
end

local function billboard(anchor, name, height, width)
    local gui = Instance.new("BillboardGui")
    gui.Name = name
    gui.Size = UDim2.fromOffset(width or 150, 44)
    gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
    gui.MaxDistance = 80
    gui.LightInfluence = 0
    gui.Parent = anchor
    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundColor3 = Colors.plum
    label.BackgroundTransparency = 0.2
    label.TextColor3 = Colors.cream
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.AutoLocalize = false
    label.Text = ""
    label.Parent = gui
    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 6)
    return label
end

local function slotPosition(center, facing, index)
    -- Two rows of five pedestals, front row closest to the avenue.
    local row = if index <= 5 then 0 else 1
    local column = (index - 1) % 5
    local x = center.X - 8 + column * 4
    local z = center.Z + facing * (2 - row * 5)
    return Vector3.new(x, 0.5, z)
end

local function buildPlot(scene, index)
    local columnIndex = (index - 1) % 4 + 1
    local rowIndex = if index <= 4 then 1 else 2
    -- +1 means the plot faces south toward the avenue, -1 north.
    local facing = if rowIndex == 1 then -1 else 1
    local center = Vector3.new(COLUMN_X[columnIndex], 0, ROW_Z[rowIndex])

    local model = Instance.new("Model")
    model.Name = "Plot" .. index
    model:SetAttribute("PlotIndex", index)
    model:SetAttribute("OwnerUserId", 0)
    model.Parent = scene

    local floor = part(model, "Floor", Vector3.new(BaseWorld.PlotSize, 0.4, BaseWorld.PlotSize),
        center + Vector3.new(0, 0.2, 0), PlotColors[index], true)
    floor.Transparency = 0.25
    model.PrimaryPart = floor

    local back = center + Vector3.new(0, 0, -facing * 10)
    local post = part(model, "SignPost", Vector3.new(1, 7, 1), back + Vector3.new(0, 3.5, 0), Colors.wood, true)
    local ownerLabel = billboard(post, "OwnerSign", 5, 190)
    CollectionService:AddTag(ownerLabel, "EggstridePlotSign")

    local collector = part(model, "Collector", Vector3.new(5, 0.5, 5),
        center + Vector3.new(8, 0.45, facing * 8), Colors.gold, false)
    collector.Material = Enum.Material.Neon
    collector.CanTouch = true
    local collectorLabel = billboard(collector, "CollectorSign", 3, 120)
    CollectionService:AddTag(collectorLabel, "EggstrideCollectorSign")

    local lock = part(model, "LockButton", Vector3.new(3, 1.2, 3),
        center + Vector3.new(-8, 0.6, facing * 8), Colors.shield, true)
    lock.Material = Enum.Material.Neon
    local lockPrompt = prompt(lock, "Закрыть базу", "LockBase")
    CollectionService:AddTag(lockPrompt, "EggstrideOwnerOnly")

    local slotButton = part(model, "SlotUpgrade", Vector3.new(3, 1.2, 3),
        center + Vector3.new(-2, 0.6, facing * 8), Colors.cream, true)
    local slotPrompt = prompt(slotButton, "Новый слот", "BuySlot")
    CollectionService:AddTag(slotPrompt, "EggstrideOwnerOnly")

    local barrier = part(model, "Barrier", Vector3.new(BaseWorld.PlotSize, 8, BaseWorld.PlotSize),
        center + Vector3.new(0, 4, 0), Colors.shield, false)
    barrier.Material = Enum.Material.ForceField
    barrier.Transparency = 1
    barrier.CastShadow = false

    local slots = {}
    for slot = 1, Bases.MaxSlots do
        local position = slotPosition(center, facing, slot)
        local pedestal = part(model, "Slot" .. slot, Vector3.new(3, 1, 3), position, Colors.rock, true)
        pedestal:SetAttribute("Slot", slot)
        local steal = prompt(pedestal, "Украсть", "Steal", Bases.StealHoldSeconds)
        steal.Enabled = false
        CollectionService:AddTag(steal, "EggstrideStealPrompt")
        slots[slot] = { pedestal = pedestal, prompt = steal }
    end

    return {
        index = index,
        model = model,
        center = center,
        facing = facing,
        floor = floor,
        collector = collector,
        lockPrompt = lockPrompt,
        slotPrompt = slotPrompt,
        barrier = barrier,
        slots = slots,
    }
end

function BaseWorld.build(parent)
    local scene = Instance.new("Folder")
    scene.Name = "EggstrideBases"
    scene.Parent = parent

    part(scene, "Основание района", Vector3.new(124, 8, 66), Vector3.new(DISTRICT_X, -6, DISTRICT_Z), Colors.rock, false)
    part(scene, "Трава района", Vector3.new(128, 2, 70), Vector3.new(DISTRICT_X, -1, DISTRICT_Z), Colors.grass, true)
    -- Bridge from the south edge of the camp island to the district.
    part(scene, "Мост к базам", Vector3.new(10, 1, 40), Vector3.new(14, -0.5, -45), Colors.wood, true)
    for _, x in ipairs({ 9.25, 18.75 }) do
        part(scene, "Бортик", Vector3.new(0.5, 1.6, 40), Vector3.new(x, 0.8, -45), Colors.cream, true)
    end

    local plots = {}
    for index = 1, Bases.PlotCount do
        plots[index] = buildPlot(scene, index)
    end
    return plots
end

-- Simple pet figure on a pedestal: body, eyes and a name tag.
function BaseWorld.showPet(slotView, pet, label)
    if slotView.figure then
        slotView.figure:Destroy()
        slotView.figure = nil
    end
    if not pet then
        return
    end
    local pedestal = slotView.pedestal
    local figure = Instance.new("Model")
    figure.Name = "Pet"
    local body = part(figure, "Body", Vector3.new(2, 2, 2), pedestal.Position + Vector3.new(0, 1.6, 0),
        Color3.fromRGB(table.unpack(pet.color)), false)
    body.Shape = Enum.PartType.Ball
    for _, side in ipairs({ -0.45, 0.45 }) do
        part(figure, "Eye", Vector3.new(0.3, 0.3, 0.3), body.Position + Vector3.new(side, 0.3, -0.9),
            Colors.plum, false).Shape = Enum.PartType.Ball
    end
    local tag = billboard(body, "PetTag", 2, 120)
    tag.Text = label
    tag:SetAttribute("SourceText", label)
    CollectionService:AddTag(tag, "EggstrideWorldText")
    figure.Parent = pedestal
    slotView.figure = figure
end

return BaseWorld
