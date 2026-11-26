-- Sky storm banner and lightning flashes.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Eggstride")
local locale = require(script.Parent.InterfaceLanguage)
local text = locale.text

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "EggstrideStorm"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 150)
banner.Size = UDim2.fromOffset(360, 36)
banner.BackgroundColor3 = Color3.fromRGB(60, 40, 110)
banner.BackgroundTransparency = 0.1
banner.TextColor3 = Color3.fromRGB(255, 215, 90)
banner.Font = Enum.Font.GothamBlack
banner.TextScaled = true
banner.Visible = false
banner.Parent = gui
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 8)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 205, 70)
stroke.Thickness = 2
stroke.Parent = banner

local function update()
    local state = Shared:GetAttribute("StormState")
    local spot = Shared:GetAttribute("StormSpot")
    local carrier = Shared:GetAttribute("StormCarrier")
    local message
    if state == "next" then
        message = text("В следующем раунде — небесный шторм!")
    elseif state == "warning" then
        message = text("Небесный шторм начинается!")
    elseif state == "active" and carrier then
        message = text("%s несёт золотое яйцо! Перехвати!", carrier)
    elseif state == "active" and spot then
        message = text("Золотое яйцо над %s! Лети через поток", text(spot))
    end
    local summoner = Shared:GetAttribute("StormSummoner")
    if message and summoner then
        message = text("Шторм от %s · ", summoner) .. message
    end
    banner.Visible = message ~= nil
    banner.Text = message or ""
end
for _, name in ipairs({ "StormState", "StormSpot", "StormCarrier", "StormSummoner" }) do
    Shared:GetAttributeChangedSignal(name):Connect(update)
end
update()

-- Local lightning: a short flash every few seconds while the storm is active.
task.spawn(function()
    local random = Random.new()
    while true do
        task.wait(random:NextNumber(3, 7))
        if Shared:GetAttribute("StormState") == "active" then
            local brightness = Lighting.Brightness
            Lighting.Brightness = brightness + 3
            task.wait(0.08)
            Lighting.Brightness = brightness
            task.wait(0.1)
            Lighting.Brightness = brightness + 2
            task.wait(0.06)
            Lighting.Brightness = brightness
        end
    end
end)
