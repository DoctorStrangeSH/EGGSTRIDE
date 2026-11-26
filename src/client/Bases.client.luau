-- Client view of player bases: localized plot signs, owner-only prompts,
-- steal/sell prompt text, robbery alert and product buttons.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Eggstride")
local Bases = require(Shared:WaitForChild("Bases"))
local LivingEgg = require(Shared:WaitForChild("LivingEgg"))
local Rebirth = require(Shared:WaitForChild("Rebirth"))
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

-- Rebirth station text follows coins and rebirths.
local rebirthPrompts = {}
local function updateRebirth()
    local rebirths = player:GetAttribute("Rebirths") or 0
    local coins = player:GetAttribute("Coins") or 0
    local cost = Rebirth.cost(rebirths)
    for prompt in pairs(rebirthPrompts) do
        if not cost then
            prompt.ObjectText = text("Перерождение")
            prompt.ActionText = text("Достигнут максимум перерождений.")
        else
            prompt.ObjectText = text("Доход ×%s → ×%s", tostring(Rebirth.incomeMultiplier(rebirths)),
                tostring(Rebirth.incomeMultiplier(rebirths + 1)))
            prompt.ActionText = if coins >= cost then text("Переродиться · %d монет", cost)
                else text("%d монет · не хватает %d", cost, cost - coins)
        end
    end
end
local function watchRebirth(prompt)
    rebirthPrompts[prompt] = true
    updateRebirth()
end
CollectionService:GetInstanceAddedSignal("EggstrideRebirthPrompt"):Connect(watchRebirth)
for _, prompt in ipairs(CollectionService:GetTagged("EggstrideRebirthPrompt")) do
    watchRebirth(prompt)
end
player:GetAttributeChangedSignal("Rebirths"):Connect(updateRebirth)
player:GetAttributeChangedSignal("Coins"):Connect(updateRebirth)

-- Robbery, stolen cargo and egg glow alerts, stacked under the HUD.
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local colors = UiKit.Colors

local function updateAlerts()
    local thief = player:GetAttribute("BaseRobbed")
    UiKit.alert("robbed", if thief then "🚨 " .. text("%s крадёт твоего питомца!", thief) else nil, colors.berry, true)
    local pet = player:GetAttribute("CarryingStolen")
    UiKit.alert("carrying", if pet then "🏃 " .. text("Неси %s на свою базу!", text(pet)) else nil, colors.violet, true)
end

local stageColors = { colors.inkSoft, colors.goldDeep, Color3.fromRGB(255, 120, 80), colors.pink }
local function updateGlow()
    local stage = player:GetAttribute("EggStage")
    local definition = stage and LivingEgg.Stages[stage]
    if not definition then
        UiKit.alert("glow", nil)
        return
    end
    local nextStage = LivingEgg.Stages[stage + 1]
    local stars = string.rep("★", stage - 1) .. string.rep("☆", #LivingEgg.Stages - stage)
    UiKit.alert("glow", "🥚 " .. text(definition.name) .. "  " .. stars .. "  ×" .. tostring(definition.coins)
        .. (if nextStage then "" else "  " .. text("Максимум!")), stageColors[stage], stage == #LivingEgg.Stages)
end
player:GetAttributeChangedSignal("EggStage"):Connect(updateGlow)
updateGlow()

player:GetAttributeChangedSignal("BaseRobbed"):Connect(updateAlerts)
player:GetAttributeChangedSignal("CarryingStolen"):Connect(updateAlerts)
updateAlerts()

-- Product buttons in the left column.
local productLook = {
    shield = { icon = "🛡", color = colors.sky },
    income = { icon = "💰", color = colors.goldDeep },
    storm = { icon = "🌩", color = colors.violet },
}
local productButtons = {}
local function refreshShop()
    local studio = Shared:GetAttribute("StudioProducts") == true
    for key, button in pairs(productButtons) do
        button.Visible = studio or Shared:GetAttribute("ProductId_" .. key) ~= nil
    end
end

for index, key in ipairs(Bases.ProductOrder) do
    local product = Bases.Products[key]
    local look = productLook[key]
    local button = UiKit.button(UiKit.sideColumn(), text(product.name), look.color, look.icon)
    button.Name = key
    button.LayoutOrder = 10 + index
    button.Size = UDim2.fromOffset(150, 44)
    button.TextSize = 15
    button.Visible = false
    productButtons[key] = button
    button.Activated:Connect(function()
        action:FireServer("Buy", key)
    end)
end
Shared:GetAttributeChangedSignal("StudioProducts"):Connect(refreshShop)
for _, key in ipairs(Bases.ProductOrder) do
    Shared:GetAttributeChangedSignal("ProductId_" .. key):Connect(refreshShop)
end
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
