local TweenService = game:GetService("TweenService")

local HatchEffects = {}

function HatchEffects.clear(parent)
    local previous = parent:FindFirstChild("HatchAnimation")
    if previous then
        previous:Destroy()
    end
end

function HatchEffects.play(parent, effect, reduceMotion)
    HatchEffects.clear(parent)
    local overlay = Instance.new("Frame")
    overlay.Name = "HatchAnimation"
    overlay.BackgroundTransparency = 1
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.ClipsDescendants = true
    overlay.Parent = parent

    local first = Color3.fromRGB(table.unpack(effect.first))
    local last = Color3.fromRGB(table.unpack(effect.last))
    local center = UDim2.fromScale(0.5, 0.5)
    local orbit = effect.pattern == "orbit"
    local petals = effect.pattern == "petals"
    local count = if orbit then 10 else 12

    local egg = Instance.new("Frame")
    egg.AnchorPoint = Vector2.new(0.5, 0.5)
    egg.Position = center
    egg.Size = UDim2.fromOffset(17, 23)
    egg.BackgroundColor3 = first
    egg.BorderSizePixel = 0
    egg.Parent = overlay
    Instance.new("UICorner", egg).CornerRadius = UDim.new(0.5, 0)

    for index = 1, count do
        local angle = (index - 1) * 2 * math.pi / count
        local distance = if orbit or index % 2 == 0 then 59 else 40
        local finish = UDim2.new(0.5, math.cos(angle) * distance, 0.5, math.sin(angle) * 16)
        local shape = Instance.new("Frame")
        shape.AnchorPoint = Vector2.new(0.5, 0.5)
        shape.Position = if reduceMotion then finish else center
        shape.Size = if petals then UDim2.fromOffset(10, 5) else UDim2.fromOffset(6, 6)
        shape.Rotation = math.deg(angle) + (if petals then 20 else 45)
        shape.BackgroundColor3 = first:Lerp(last, (index - 1) / (count - 1))
        shape.BorderSizePixel = 0
        if orbit or petals then
            Instance.new("UICorner", shape).CornerRadius = UDim.new(0.5, 0)
        end
        shape.Parent = overlay

        if not reduceMotion then
            local launch = TweenService:Create(shape,
                TweenInfo.new(0.48, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, index * 0.016),
                { Position = finish, Rotation = shape.Rotation + (if orbit then 120 else 48), BackgroundTransparency = 0.32 })
            launch:Play()
        end
    end

    task.delay(1.4, function()
        overlay:Destroy()
    end)
end

return HatchEffects
