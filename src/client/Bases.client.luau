-- Client view of player bases: localized plot signs, owner-only prompts,
-- steal/sell prompt text, robbery alert and product buttons.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Eggstride")
local Bases = require(Shared:WaitForChild("Bases"))
local LivingEgg = require(Shared:WaitForChild("LivingEgg"))
local locale = require(script.Parent.InterfaceLanguage)
local text = locale.text

local player = Players.LocalPlayer
local action = Shared:WaitForChild("BaseAction")

local function plotOf(instance)
    local node = instance
    while node and not (node:IsA("Model") and node:GetAttribute("PlotIndex")) do
        node = node.Parent
    end
    return node
end

local function isMine(plot)
    return plot and plot:GetAttribute("OwnerUserId") == player.UserId
end

local function secondsLeft(plot, now)
    local lock = math.max(plot:GetAttribute("LockedUntil") or 0, plot:GetAttribute("ShieldUntil") or 0)
    return math.max(0, math.ceil(lock - now))
end

local function refreshPrompt(prompt)
    local plot = plotOf(prompt)
    if not plot then
        return
    end
    local mine = isMine(plot)
    if CollectionService:HasTag(prompt, "EggstrideOwnerOnly") then
        prompt.Enabled = mine
        if prompt.Name == "BuySlot" then
            local cost = plot:GetAttribute("NextSlotCost") or 0
            prompt.ActionText = if cost > 0 then text("Новый слот · %d монет", cost) else text("Максимум слотов")
        end
    elseif CollectionService:HasTag(prompt, "EggstrideStealPrompt") then
        local name = prompt.Parent:GetAttribute("PetName") or ""
        prompt.ObjectText = if name ~= "" then text(name) else ""
        if mine then
            local price = prompt.Parent:GetAttribute("SellPrice") or 0
            prompt.ActionText = if price > 0 then text("Продать · %d монет", price) else text("Продать")
            prompt.HoldDuration = 0.8
        else
            prompt.ActionText = text("Украсть")
            prompt.HoldDuration = Bases.StealHoldSeconds
        end
    end
end

local watched = {}
local function watchPrompt(prompt)
    if watched[prompt] then
        return
    end
    watched[prompt] = true
    local plot = plotOf(prompt)
    if plot then
        plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
            refreshPrompt(prompt)
        end)
        plot:GetAttributeChangedSignal("NextSlotCost"):Connect(function()
            refreshPrompt(prompt)
        end)
    end
    if prompt.Parent then
        prompt.Parent:GetAttributeChangedSignal("PetId"):Connect(function()
            refreshPrompt(prompt)
        end)
    end
    refreshPrompt(prompt)
end

for _, tag in ipairs({ "EggstrideOwnerOnly", "EggstrideStealPrompt" }) do
    CollectionService:GetInstanceAddedSignal(tag):Connect(watchPrompt)
    for _, prompt in ipairs(CollectionService:GetTagged(tag)) do
        watchPrompt(prompt)
    end
end

-- Interception prompts hang on carriers: hide your own, translate the rest.
local function watchIntercept(prompt)
    prompt.ActionText = text("Перехватить")
    prompt.ObjectText = text(prompt:GetAttribute("ObjectSource") or "Сияющее яйцо")
    if prompt:GetAttribute("CarrierUserId") == player.UserId then
        prompt.Enabled = false
    end
end
CollectionService:GetInstanceAddedSignal("EggstrideInterceptPrompt"):Connect(watchIntercept)
for _, prompt in ipairs(CollectionService:GetTagged("EggstrideInterceptPrompt")) do
    watchIntercept(prompt)
end

local function watchBounty(label)
    label.Text = text("Вор! Награда %d", label:GetAttribute("Bounty") or 0)
end
CollectionService:GetInstanceAddedSignal("EggstrideBountySign"):Connect(watchBounty)
for _, label in ipairs(CollectionService:GetTagged("EggstrideBountySign")) do
    watchBounty(label)
end

-- Robbery alert and product buttons.
local gui = Instance.new("ScreenGui")
gui.Name = "EggstrideBases"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local alert = Instance.new("TextLabel")
alert.Name = "RobberyAlert"
alert.AnchorPoint = Vector2.new(0.5, 0)
alert.Position = UDim2.new(0.5, 0, 0, 64)
alert.Size = UDim2.fromOffset(320, 40)
alert.BackgroundColor3 = Color3.fromRGB(200, 50, 70)
alert.TextColor3 = Color3.new(1, 1, 1)
alert.Font = Enum.Font.GothamBold
alert.TextScaled = true
alert.Visible = false
alert.Parent = gui
Instance.new("UICorner", alert).CornerRadius = UDim.new(0, 8)

local carrying = alert:Clone()
carrying.Name = "CarryingStolen"
carrying.BackgroundColor3 = Color3.fromRGB(70, 60, 140)
carrying.Parent = gui

local function updateAlerts()
    local thief = player:GetAttribute("BaseRobbed")
    alert.Visible = thief ~= nil
    alert.Text = if thief then text("%s крадёт твоего питомца!", thief) else ""
    local pet = player:GetAttribute("CarryingStolen")
    carrying.Visible = pet ~= nil
    carrying.Text = if pet then text("Неси %s на свою базу!", text(pet)) else ""
end
local glow = alert:Clone()
glow.Name = "EggGlow"
glow.Position = UDim2.new(0.5, 0, 0, 110)
glow.Size = UDim2.fromOffset(260, 32)
glow.BackgroundColor3 = Color3.fromRGB(240, 170, 50)
glow.Parent = gui

local function updateGlow()
    local stage = player:GetAttribute("EggStage")
    local definition = stage and LivingEgg.Stages[stage]
    glow.Visible = definition ~= nil
    if definition then
        local nextStage = LivingEgg.Stages[stage + 1]
        glow.Text = text(definition.name) .. "  ·  ×" .. tostring(definition.coins)
            .. (if nextStage then "" else "  ·  " .. text("Максимум!"))
        glow.BackgroundColor3 = Color3.fromRGB(240, 170, 50):Lerp(Color3.fromRGB(255, 90, 200), (stage - 1) / 3)
    end
end
player:GetAttributeChangedSignal("EggStage"):Connect(updateGlow)
updateGlow()

player:GetAttributeChangedSignal("BaseRobbed"):Connect(updateAlerts)
player:GetAttributeChangedSignal("CarryingStolen"):Connect(updateAlerts)
updateAlerts()

local shop = Instance.new("Frame")
shop.Name = "BaseProducts"
shop.AnchorPoint = Vector2.new(0, 1)
shop.Position = UDim2.new(0, 12, 1, -12)
shop.Size = UDim2.fromOffset(150, 84)
shop.BackgroundTransparency = 1
shop.Visible = false
shop.Parent = gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.Parent = shop

local function refreshShop()
    local studio = Shared:GetAttribute("StudioProducts") == true
    local any = studio
    for _, key in ipairs(Bases.ProductOrder) do
        if Shared:GetAttribute("ProductId_" .. key) then
            any = true
        end
    end
    shop.Visible = any
end

for index, key in ipairs(Bases.ProductOrder) do
    local product = Bases.Products[key]
    local button = Instance.new("TextButton")
    button.Name = key
    button.LayoutOrder = index
    button.Size = UDim2.fromOffset(150, 38)
    button.BackgroundColor3 = if key == "shield" then Color3.fromRGB(80, 150, 230) else Color3.fromRGB(240, 170, 50)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.GothamBold
    button.TextScaled = true
    button.Text = text(product.name)
    button.Parent = shop
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
    button.Activated:Connect(function()
        action:FireServer("Buy", key)
    end)
end
Shared:GetAttributeChangedSignal("StudioProducts"):Connect(refreshShop)
refreshShop()

-- Signs and barriers change every second, so redraw them on a timer.
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed < 0.25 then
        return
    end
    elapsed = 0
    local now = workspace:GetServerTimeNow()
    for _, label in ipairs(CollectionService:GetTagged("EggstridePlotSign")) do
        local plot = plotOf(label)
        if plot then
            local owner = plot:GetAttribute("OwnerName")
            local locked = secondsLeft(plot, now)
            if not owner then
                label.Text = text("Свободная база")
            else
                local line = text("База %s · %d/мин", owner, plot:GetAttribute("Income") or 0)
                if (plot:GetAttribute("BoostUntil") or 0) > now then
                    line ..= " · ×2"
                end
                label.Text = line .. "\n" .. (if locked > 0 then text("Закрыта · %d с", locked) else text("Открыта"))
            end
            local barrier = plot:FindFirstChild("Barrier")
            if barrier then
                barrier.Transparency = if owner and locked > 0 then 0.6 else 1
            end
        end
    end
    for _, label in ipairs(CollectionService:GetTagged("EggstrideCollectorSign")) do
        local plot = plotOf(label)
        if plot then
            label.Text = if isMine(plot) then text("Собрать · %d", plot:GetAttribute("Pending") or 0) else ""
            label.Parent.Enabled = isMine(plot)
        end
    end
    for _, prompt in ipairs(CollectionService:GetTagged("EggstrideOwnerOnly")) do
        if prompt.Name == "LockBase" then
            local plot = plotOf(prompt)
            local locked = plot and secondsLeft(plot, now) or 0
            prompt.ActionText = if locked > 0 then text("Закрыта · %d с", locked) else text("Закрыть базу")
        end
    end
end)
