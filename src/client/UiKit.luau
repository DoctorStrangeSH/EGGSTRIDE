-- Shared look and responsive scaling for every EGGSTRIDE screen.
-- Sizes are designed for a phone at scale 1 (44 px touch targets) and grow on
-- bigger screens. UIScale goes on size-capped containers, never on full-screen
-- frames, so nothing overflows the screen.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UiKit = {}

UiKit.Colors = {
    ink = Color3.fromRGB(28, 24, 54),
    inkSoft = Color3.fromRGB(48, 42, 88),
    cream = Color3.fromRGB(255, 248, 228),
    gold = Color3.fromRGB(255, 205, 86),
    goldDeep = Color3.fromRGB(240, 150, 40),
    mint = Color3.fromRGB(130, 245, 190),
    sky = Color3.fromRGB(110, 190, 255),
    berry = Color3.fromRGB(255, 92, 128),
    violet = Color3.fromRGB(150, 100, 255),
    pink = Color3.fromRGB(255, 120, 200),
    danger = Color3.fromRGB(255, 110, 100),
}
UiKit.Font = Font.fromEnum(Enum.Font.FredokaOne)
UiKit.BodyFont = Font.fromEnum(Enum.Font.GothamBold)

-- Scale for the current screen: 1 on phones, up to 1.6 on large monitors.
function UiKit.scaleFor(viewport)
    local raw = math.min(viewport.X / 1000, viewport.Y / 600)
    local minimum = if viewport.Y < 340 then 0.9 else 1
    return math.clamp(raw, minimum, 1.6)
end

local scales = {}
local function currentScale()
    local camera = workspace.CurrentCamera
    return if camera then UiKit.scaleFor(camera.ViewportSize) else 1
end
local function refreshScales()
    local value = currentScale()
    for scale in pairs(scales) do
        if scale.Parent then
            scale.Scale = value
        else
            scales[scale] = nil
        end
    end
end
local function watchCamera()
    local camera = workspace.CurrentCamera
    if camera then
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScales)
    end
    refreshScales()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

-- Attach responsive scaling to a size-capped container.
function UiKit.scaled(container)
    local scale = Instance.new("UIScale")
    scale.Name = "ResponsiveScale"
    scale.Scale = currentScale()
    scale.Parent = container
    scales[scale] = true
    return scale
end

function UiKit.isTouch()
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function UiKit.corner(item, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 12)
    corner.Parent = item
    return corner
end

function UiKit.stroke(item, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or UiKit.Colors.ink
    stroke.Thickness = thickness or 2
    stroke.Transparency = transparency or 0
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = item
    return stroke
end

-- Text outline keeps labels readable over bright skies.
function UiKit.textStroke(label, color)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or UiKit.Colors.ink
    stroke.Thickness = 1.5
    stroke.Transparency = 0.2
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    stroke.Parent = label
    return stroke
end

function UiKit.gradient(item, top, bottom, rotation)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new(top, bottom)
    gradient.Rotation = rotation or 90
    gradient.Parent = item
    return gradient
end

function UiKit.padding(item, horizontal, vertical)
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, horizontal)
    padding.PaddingRight = UDim.new(0, horizontal)
    padding.PaddingTop = UDim.new(0, vertical or horizontal)
    padding.PaddingBottom = UDim.new(0, vertical or horizontal)
    padding.Parent = item
    return padding
end

function UiKit.list(item, gap, direction, align)
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, gap or 6)
    layout.FillDirection = direction or Enum.FillDirection.Vertical
    layout.HorizontalAlignment = align or Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Parent = item
    return layout
end

function UiKit.label(parent, text, size, color, font)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.FontFace = font or UiKit.Font
    label.TextSize = size or 16
    label.TextColor3 = color or UiKit.Colors.cream
    label.Text = text or ""
    label.AutoLocalize = false
    label.TextWrapped = true
    label.Size = UDim2.new(1, 0, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.Parent = parent
    return label
end

-- Dark rounded card with a soft gradient and a light rim.
function UiKit.panel(parent, name)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.BackgroundColor3 = UiKit.Colors.ink
    frame.BackgroundTransparency = 0.08
    frame.Parent = parent
    UiKit.corner(frame, 14)
    UiKit.gradient(frame, Color3.new(1, 1, 1), Color3.fromRGB(170, 160, 210))
    UiKit.stroke(frame, Color3.fromRGB(255, 255, 255), 1.5, 0.8)
    return frame
end

-- Chunky button: gradient, dark rim, springy press. Activated works for mouse, touch and gamepad.
function UiKit.button(parent, text, color, icon)
    local button = Instance.new("TextButton")
    button.AutoButtonColor = false
    button.BackgroundColor3 = color or UiKit.Colors.gold
    button.FontFace = UiKit.Font
    button.TextSize = 16
    button.TextColor3 = UiKit.Colors.cream
    button.Text = if icon then icon .. "  " .. text else text
    button.AutoLocalize = false
    button.TextWrapped = true
    button.Size = UDim2.fromOffset(140, 44)
    button.Parent = parent
    UiKit.corner(button, 12)
    UiKit.gradient(button, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
    UiKit.stroke(button, UiKit.Colors.ink, 2.5)
    UiKit.textStroke(button)
    local scale = Instance.new("UIScale")
    scale.Parent = button
    local function to(value, time)
        TweenService:Create(scale, TweenInfo.new(time, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = value }):Play()
    end
    button.MouseEnter:Connect(function()
        to(1.06, 0.15)
    end)
    button.MouseLeave:Connect(function()
        to(1, 0.15)
    end)
    button.MouseButton1Down:Connect(function()
        to(0.92, 0.08)
    end)
    button.MouseButton1Up:Connect(function()
        to(1, 0.2)
    end)
    return button
end

-- Small rounded tag with an icon, used for stats and alerts.
function UiKit.pill(parent, name, color)
    local pill = Instance.new("TextLabel")
    pill.Name = name
    pill.BackgroundColor3 = color or UiKit.Colors.inkSoft
    pill.FontFace = UiKit.Font
    pill.TextSize = 16
    pill.TextColor3 = UiKit.Colors.cream
    pill.AutoLocalize = false
    pill.AutomaticSize = Enum.AutomaticSize.XY
    pill.Size = UDim2.fromOffset(0, 30)
    pill.Text = ""
    pill.Parent = parent
    UiKit.corner(pill, 15)
    UiKit.padding(pill, 12, 5)
    UiKit.stroke(pill, UiKit.Colors.ink, 2)
    UiKit.textStroke(pill)
    UiKit.gradient(pill, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))
    local limit = Instance.new("UISizeConstraint")
    limit.MaxSize = Vector2.new(340, math.huge)
    limit.Parent = pill
    pill.TextWrapped = true
    return pill
end

-- Pop-in animation for anything that just appeared.
function UiKit.pop(item)
    local scale = item:FindFirstChild("PopScale") or Instance.new("UIScale")
    scale.Name = "PopScale"
    scale.Scale = 0.6
    scale.Parent = item
    TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Gentle repeating pulse for urgent alerts. Returns a stop function.
function UiKit.pulse(item)
    local scale = item:FindFirstChild("PulseScale") or Instance.new("UIScale")
    scale.Name = "PulseScale"
    scale.Parent = item
    local tween = TweenService:Create(scale, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Scale = 1.06 })
    tween:Play()
    return function()
        tween:Cancel()
        scale.Scale = 1
    end
end

-- Alert pills stack under the HUD. Each source owns one pill by key.
local alerts = {}
local alertOrder = 0
function UiKit.alertStack()
    local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    return playerGui:WaitForChild("EggstrideHud"):WaitForChild("Top"):WaitForChild("Alerts")
end

-- Shows, updates or hides (text == nil) the alert with this key.
function UiKit.alert(key, text, color, urgent)
    local record = alerts[key]
    if not text then
        if record then
            if record.stop then
                record.stop()
            end
            record.pill:Destroy()
            alerts[key] = nil
        end
        return
    end
    if not record then
        alertOrder += 1
        record = { pill = UiKit.pill(UiKit.alertStack(), "Alert_" .. key, color) }
        record.pill.LayoutOrder = alertOrder
        alerts[key] = record
        UiKit.pop(record.pill)
    end
    record.pill.BackgroundColor3 = color or UiKit.Colors.inkSoft
    record.pill.Text = text
    if urgent and not record.stop then
        record.stop = UiKit.pulse(record.pill)
    elseif not urgent and record.stop then
        record.stop()
        record.stop = nil
    end
end

-- Alert that disappears by itself.
function UiKit.toast(key, text, color, seconds)
    UiKit.alert(key, text, color)
    local record = alerts[key]
    record.token = (record.token or 0) + 1
    local token = record.token
    task.delay(seconds or 3, function()
        if alerts[key] == record and record.token == token then
            UiKit.alert(key, nil)
        end
    end)
end

-- Left-edge column for big action buttons, clear of the mobile thumbstick and jump button.
function UiKit.sideColumn()
    local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    return playerGui:WaitForChild("EggstrideHud"):WaitForChild("Side")
end

-- Smoothly counts a number label up or down.
function UiKit.countTo(holder, value, format)
    local current = holder:GetAttribute("Shown") or value
    holder:SetAttribute("Target", value)
    local started = os.clock()
    task.spawn(function()
        while holder:GetAttribute("Target") == value do
            local t = math.min(1, (os.clock() - started) / 0.4)
            local shown = math.floor(current + (value - current) * (1 - (1 - t) ^ 3) + 0.5)
            holder:SetAttribute("Shown", shown)
            holder.Text = format(shown)
            if t >= 1 then
                break
            end
            task.wait()
        end
    end)
end

return UiKit
