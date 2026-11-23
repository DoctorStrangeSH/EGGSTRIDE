local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage:WaitForChild("Eggstride"):WaitForChild("Rules"))
local locale = require(script.Parent.InterfaceLanguage)

local tag = "EggstrideWorldText"
local connections = {}
local player = Players.LocalPlayer
local speedPrompt

local function updateSpeedPrompt()
    if not speedPrompt then
        return
    end
    local tier = player:GetAttribute("SpeedTier")
    local coins = player:GetAttribute("Coins")
    local text = locale.text
    if tier == nil or coins == nil then
        speedPrompt.ObjectText = text("Прокачка скорости")
        speedPrompt.ActionText = text("Загружаем прогресс…")
        return
    end

    local cost, vault, missing = Rules.nextSpeedUpgrade(tier, coins)
    if not cost then
        speedPrompt.ObjectText = text("Прокачка скорости")
        speedPrompt.ActionText = text("Максимум скорости")
        return
    end
    speedPrompt.ObjectText = if vault then text("Откроет %s остров", text(vault.name))
        else text("Скорость %d → %d", tier, tier + 1)
    speedPrompt.ActionText = if missing > 0 then text("%d монет · не хватает %d", cost, missing)
        else text("Улучшить · %d монет", cost)
end

player:GetAttributeChangedSignal("SpeedTier"):Connect(updateSpeedPrompt)
player:GetAttributeChangedSignal("Coins"):Connect(updateSpeedPrompt)

local function bind(instance)
    if connections[instance] then
        return
    end
    if instance:IsA("ProximityPrompt") and instance.Name == "SpeedUpgrade" then
        speedPrompt = instance
        updateSpeedPrompt()
        return
    end
    local function display()
        local source = instance:GetAttribute("SourceText")
        if not source then
            return
        end
        if instance:IsA("TextLabel") then
            -- Wind signs have two independently translated lines.
            local first, second = string.match(source, "^([^\n]+)\n([^\n]+)$")
            instance.Text = if first then locale.text(first) .. "\n" .. locale.text(second) else locale.text(source)
        elseif instance:IsA("ProximityPrompt") then
            instance.ActionText = locale.text(source)
        end
    end
    connections[instance] = instance:GetAttributeChangedSignal("SourceText"):Connect(display)
    display()
end

CollectionService:GetInstanceAddedSignal(tag):Connect(bind)
CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
    if speedPrompt == instance then
        speedPrompt = nil
    end
    local connection = connections[instance]
    if connection then
        connection:Disconnect()
        connections[instance] = nil
    end
end)
for _, instance in ipairs(CollectionService:GetTagged(tag)) do
    bind(instance)
end
