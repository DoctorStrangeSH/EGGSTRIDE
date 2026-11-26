-- Launch pads, updraft columns and glider wings that other players can see.
-- Glide physics run on the client, which owns its character.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Eggstride")
local Glide = require(Shared.Glide)

local GlideService = {}

local Colors = {
    pad = Color3.fromRGB(123, 208, 250),
    wing = Color3.fromRGB(255, 240, 200),
    plum = Color3.fromRGB(40, 37, 73),
    cream = Color3.fromRGB(255, 223, 155),
}

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

local function sign(anchor, text)
    local gui = Instance.new("BillboardGui")
    gui.Size = UDim2.fromOffset(120, 28)
    gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
    gui.MaxDistance = 60
    gui.LightInfluence = 0
    gui.Parent = anchor
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundColor3 = Colors.plum
    label.BackgroundTransparency = 0.18
    label.TextColor3 = Colors.cream
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.AutoLocalize = false
    label.Text = text
    label:SetAttribute("SourceText", text)
    CollectionService:AddTag(label, "EggstrideWorldText")
    label.Parent = gui
    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 6)
end

local function rising(parent, color, speed, rate)
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(color)
    emitter.LightEmission = 0.6
    emitter.Size = NumberSequence.new(0.6, 0)
    emitter.Transparency = NumberSequence.new(0.2, 1)
    emitter.Speed = NumberRange.new(speed)
    emitter.Lifetime = NumberRange.new(1.2, 1.8)
    emitter.Rate = rate
    emitter.EmissionDirection = Enum.NormalId.Top
    emitter.Parent = parent
    return emitter
end

function GlideService.build(parent)
    local folder = Instance.new("Folder")
    folder.Name = "EggstrideGlide"
    folder.Parent = parent

    for _, pad in ipairs(Glide.Pads) do
        local plate = part(folder, "Трамплин", Vector3.new(6, 0.4, 6), CFrame.new(pad.x, 0.2, pad.z), Colors.pad)
        plate.CanTouch = true
        plate:SetAttribute("PadId", pad.id)
        CollectionService:AddTag(plate, "EggstrideLaunchPad")
        rising(plate, Colors.pad, 12, 18)
        -- Arrow toward the next island.
        local arrow = part(folder, "Стрелка", Vector3.new(3, 0.1, 0.6),
            CFrame.new(pad.x + pad.direction * 1.2, 0.45, pad.z), Colors.cream)
        local head = part(folder, "Стрелка", Vector3.new(0.6, 0.1, 2),
            CFrame.new(pad.x + pad.direction * 2.6, 0.45, pad.z), Colors.cream)
        head.Parent = arrow
        sign(plate, "Трамплин · " .. pad.label)
    end

    for _, updraft in ipairs(Glide.Updrafts) do
        local height = updraft.height + 30
        local column = part(folder, "Восходящий поток",
            Vector3.new(height, updraft.radius * 2, updraft.radius * 2),
            CFrame.new(updraft.x, updraft.height - height / 2, updraft.z) * CFrame.Angles(0, 0, math.pi / 2),
            Colors.pad)
        column.Shape = Enum.PartType.Cylinder
        column.Transparency = 0.85
        -- The column is rotated, so its Right face points up.
        rising(column, Colors.cream, 30, 40).EmissionDirection = Enum.NormalId.Right
    end

    local remote = Instance.new("RemoteEvent")
    remote.Name = "Glide"
    remote.Parent = Shared
    local nextAt = {}
    remote.OnServerEvent:Connect(function(player, gliding)
        if typeof(gliding) ~= "boolean" then
            return
        end
        local now = os.clock()
        if now < (nextAt[player] or 0) then
            return
        end
        nextAt[player] = now + 0.15
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then
            return
        end
        local existing = root:FindFirstChild("EggstrideGlider")
        if not gliding or player:GetAttribute("WeeklyStep") ~= nil then
            if existing then
                existing:Destroy()
            end
            return
        end
        if existing then
            return
        end
        local wing = Instance.new("Part")
        wing.Name = "EggstrideGlider"
        wing.Size = Vector3.new(9, 0.25, 2.6)
        wing.Color = Colors.wing
        wing.Material = Enum.Material.Fabric
        wing.CanCollide = false
        wing.CanTouch = false
        wing.CanQuery = false
        wing.Massless = true
        wing.CFrame = root.CFrame * CFrame.new(0, 2.6, 0.3)
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = root
        weld.Part1 = wing
        weld.Parent = wing
        local trail = rising(wing, Colors.cream, 2, 12)
        trail.EmissionDirection = Enum.NormalId.Back
        wing.Parent = root
    end)
    game:GetService("Players").PlayerRemoving:Connect(function(player)
        nextAt[player] = nil
    end)
end

return GlideService
