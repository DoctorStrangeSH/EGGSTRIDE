local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Eggstride")
local Rules = require(shared:WaitForChild("Rules"))
local equipPet = shared:WaitForChild("EquipPet")
local updatePreference = shared:WaitForChild("UpdatePreference")

local palette = {
    panel = Color3.fromRGB(37, 34, 65),
    row = Color3.fromRGB(55, 51, 86),
    text = Color3.fromRGB(255, 251, 231),
    muted = Color3.fromRGB(193, 190, 215),
    gold = Color3.fromRGB(255, 209, 117),
    mint = Color3.fromRGB(163, 255, 201),
}

local function textItem(className, parent, text, size, color)
    local item = Instance.new(className)
    item.BackgroundTransparency = 1
    item.Text = text
    item.Font = Enum.Font.GothamBold
    item.TextSize = size
    item.TextColor3 = color
    item.Parent = parent
    return item
end

local function fill(item, color, radius)
    item.BackgroundColor3 = color
    item.BackgroundTransparency = 0
    Instance.new("UICorner", item).CornerRadius = UDim.new(0, radius)
end

local gui = Instance.new("ScreenGui")
gui.Name = "EggstrideJournal"
gui.DisplayOrder = 2
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
local playerGui = player:WaitForChild("PlayerGui")
gui.Parent = playerGui

local header = playerGui:WaitForChild("EggstrideHud"):WaitForChild("Status"):WaitForChild("Header")
local open = textItem("TextButton", header, "Питомцы", 13, palette.panel)
open.AnchorPoint = Vector2.new(1, 0)
open.Position = UDim2.fromScale(1, 0)
open.Size = UDim2.fromOffset(102, 44)
fill(open, palette.gold, 9)

local scrim = Instance.new("Frame")
scrim.Name = "Collection"
scrim.Size = UDim2.fromScale(1, 1)
scrim.BackgroundColor3 = Color3.new(0, 0, 0)
scrim.BackgroundTransparency = 0.42
scrim.Active = true
scrim.Visible = false
scrim.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(1, -16, 1, -16)
panel.Parent = scrim
fill(panel, palette.panel, 12)
Instance.new("UISizeConstraint", panel).MaxSize = Vector2.new(440, 500)

local title = textItem("TextLabel", panel, "Коллекция", 17, palette.text)
title.Position = UDim2.fromOffset(12, 4)
title.Size = UDim2.new(1, -108, 0, 44)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextWrapped = true

local close = textItem("TextButton", panel, "Закрыть", 13, palette.text)
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -8, 0, 4)
close.Size = UDim2.fromOffset(80, 44)
fill(close, palette.row, 9)

local function updateLauncher()
    local racing = player:GetAttribute("WeeklyStartsAt") ~= nil
    if racing then
        scrim.Visible = false
    end
    open.Visible = not (racing or scrim.Visible)
end

open.Activated:Connect(function()
    scrim.Visible = true
    updateLauncher()
end)
close.Activated:Connect(function()
    scrim.Visible = false
    updateLauncher()
end)
player:GetAttributeChangedSignal("WeeklyStartsAt"):Connect(updateLauncher)
updateLauncher()

local list = Instance.new("ScrollingFrame")
list.Name = "Species"
list.Position = UDim2.fromOffset(8, 54)
list.Size = UDim2.new(1, -16, 1, -62)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.ScrollBarThickness = 4
list.Parent = panel
local layout = Instance.new("UIListLayout", list)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 6)

local settings = textItem("TextButton", list, "Настройки забега", 14, palette.panel)
settings.LayoutOrder = -3
settings.Size = UDim2.new(1, -8, 0, 44)
fill(settings, palette.gold, 10)

local settingButtons = {}
for index, option in ipairs({
    { attribute = "MuteRunSounds", off = "Звуки забега · выкл.", on = "Звуки забега · вкл." },
    { attribute = "ReduceCardMotion", off = "Карточки · без анимации", on = "Карточки · с анимацией" },
}) do
    local control = textItem("TextButton", list, "", 14, palette.text)
    control.LayoutOrder = index - 3
    control.Size = UDim2.new(1, -8, 0, 44)
    control.Visible = false
    fill(control, palette.row, 10)
    table.insert(settingButtons, control)

    local function updateSetting()
        local value = player:GetAttribute(option.attribute)
        control.Text = if value == nil then "Загрузка настроек…" elseif value then option.off else option.on
        control.Active = value ~= nil
        control.Selectable = value ~= nil
    end
    player:GetAttributeChangedSignal(option.attribute):Connect(updateSetting)
    control.Activated:Connect(function()
        local value = player:GetAttribute(option.attribute)
        if value ~= nil then
            updatePreference:FireServer(option.attribute, not value)
        end
    end)
    updateSetting()
end

settings.Activated:Connect(function()
    local expanded = not settingButtons[1].Visible
    settings.Text = if expanded then "Скрыть настройки" else "Настройки забега"
    for _, control in ipairs(settingButtons) do
        control.Visible = expanded
    end
end)

local function description(name, order, color)
    local label = textItem("TextLabel", list, "", 13, color)
    label.Name = name
    label.LayoutOrder = order
    label.Size = UDim2.new(1, -8, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.TextWrapped = true
    fill(label, palette.row, 9)
    local padding = Instance.new("UIPadding", label)
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    return label
end

local trial = description("StormTrial", 0, palette.gold)
local weekly = description("WeeklyBest", 1, palette.text)

local round = shared:WaitForChild("Round")
local leaderboardFeed = round:WaitForChild("WeeklyLeaderboard")
local boardButton = textItem("TextButton", list, "Показать топ недели", 13, palette.panel)
boardButton.LayoutOrder = 2
boardButton.Size = UDim2.new(1, -8, 0, 44)
fill(boardButton, palette.gold, 10)
local board = description("WeeklyLeaderboard", 3, palette.text)
board.Visible = false

boardButton.Activated:Connect(function()
    board.Visible = not board.Visible
    boardButton.Text = if board.Visible then "Скрыть топ недели" else "Показать топ недели"
end)

local function updateBoard()
    local titleText = if leaderboardFeed:GetAttribute("SessionOnly") then "Рейтинг тестовой сессии" else "Общий рейтинг недели"
    board.Text = titleText .. "\n" .. leaderboardFeed.Value
end

leaderboardFeed:GetPropertyChangedSignal("Value"):Connect(updateBoard)
leaderboardFeed:GetAttributeChangedSignal("SessionOnly"):Connect(updateBoard)
updateBoard()

local rows = {}
local recordLabels = {}
local order = 3

for _, vault in ipairs(Rules.Vaults) do
    order += 1
    local record = description("DeliveryRecord_" .. vault.id, order, palette.gold)
    record.BackgroundTransparency = 1
    recordLabels[vault] = record
    for _, pet in ipairs({ vault.pets.common, vault.pets.rare }) do
        local row = Instance.new("Frame")
        row.Name = pet.id
        order += 1
        row.LayoutOrder = order
        row.Size = UDim2.new(1, -8, 0, 0)
        row.AutomaticSize = Enum.AutomaticSize.Y
        row.Parent = list
        fill(row, palette.row, 10)

        local copy = Instance.new("Frame")
        copy.BackgroundTransparency = 1
        copy.Size = UDim2.new(1, -104, 0, 0)
        copy.AutomaticSize = Enum.AutomaticSize.Y
        copy.Parent = row
        local copyPadding = Instance.new("UIPadding", copy)
        copyPadding.PaddingLeft = UDim.new(0, 10)
        copyPadding.PaddingTop = UDim.new(0, 8)
        copyPadding.PaddingBottom = UDim.new(0, 8)
        local copyLayout = Instance.new("UIListLayout", copy)
        copyLayout.SortOrder = Enum.SortOrder.LayoutOrder
        copyLayout.Padding = UDim.new(0, 2)

        local name = textItem("TextLabel", copy, pet.name, 14, palette.text)
        name.Size = UDim2.new(1, 0, 0, 0)
        name.AutomaticSize = Enum.AutomaticSize.Y
        name.TextWrapped = true
        name.TextXAlignment = Enum.TextXAlignment.Left

        local commonEggOdds = Rules.RarePetChance["Обычное"]
        local rareEggOdds = Rules.RarePetChance["Редкое"]
        if pet == vault.pets.common then
            commonEggOdds, rareEggOdds = 100 - commonEggOdds, 100 - rareEggOdds
        end
        local condition = string.format("%s\nИз обычного яйца %d%%, редкого %d%%",
            pet.rarity, commonEggOdds, rareEggOdds)
        local details = textItem("TextLabel", copy, condition, 12, palette.muted)
        details.LayoutOrder = 1
        details.Size = UDim2.new(1, 0, 0, 0)
        details.AutomaticSize = Enum.AutomaticSize.Y
        details.TextXAlignment = Enum.TextXAlignment.Left
        details.TextWrapped = true

        local action = textItem("TextButton", row, "", 12, palette.panel)
        action.AnchorPoint = Vector2.new(1, 0)
        action.Position = UDim2.new(1, -8, 0, 8)
        action.Size = UDim2.fromOffset(86, 44)
        fill(action, palette.muted, 9)
        action.Activated:Connect(function()
            if player:GetAttribute("OwnsPet_" .. pet.id) and player:GetAttribute("EquippedPetId") ~= pet.id then
                equipPet:FireServer(pet.id)
            end
        end)
        table.insert(rows, { id = pet.id, action = action })
    end
end

local function update()
    local equipped = player:GetAttribute("EquippedPetId")
    local time = player:GetAttribute("WeeklyBest")
    local heading = if time then "Рекорд недели · " .. Rules.deliveryTimeText(time)
        else "Забег недели · вход в лагере"
    local reward = if player:GetAttribute("WeeklyRewardClaimed") then "Награда недели получена"
        else string.format("Награда: %d монет за зачётный финиш ≤ %d сек.",
            Rules.Weekly.rewardCoins, Rules.Weekly.rewardTime / 1000)
    weekly.Text = heading .. "\n" .. reward
    if player:GetAttribute("StormTrailUnlocked") then
        trial.Text = Rules.StormTrial.name .. "\nОткрыт и применён к спутнику"
    else
        trial.Text = string.format("%s\nДоставь грозовое яйцо через маяк, пока на таймере %d+ сек.",
            Rules.StormTrial.name, Rules.StormTrial.secondsLeft)
    end
    for vault, label in pairs(recordLabels) do
        local time = player:GetAttribute("DeliveryRecord_" .. vault.id)
        label.Text = vault.name .. (if time then " · Рекорд " .. Rules.deliveryTimeText(time) else " · Пока без рекорда")
    end
    local count = 0
    for _, row in ipairs(rows) do
        local owned = player:GetAttribute("OwnsPet_" .. row.id) == true
        local selected = owned and equipped == row.id
        if owned then
            count += 1
        end
        row.action.Text = if selected then "Спутник" elseif owned then "Выбрать" else "Не открыт"
        row.action.BackgroundColor3 = if selected then palette.mint elseif owned then palette.gold else palette.muted
        row.action.Active = owned and not selected
        row.action.Selectable = owned and not selected
        row.action.AutoButtonColor = owned and not selected
    end
    open.Text = string.format("Питомцы %d/%d", count, #rows)
    title.Text = string.format("Коллекция %d/%d", count, #rows)
end

player:GetAttributeChangedSignal("EquippedPetId"):Connect(update)
player:GetAttributeChangedSignal("WeeklyBest"):Connect(update)
player:GetAttributeChangedSignal("WeeklyRewardClaimed"):Connect(update)
player:GetAttributeChangedSignal("StormTrailUnlocked"):Connect(update)
for vault in pairs(recordLabels) do
    player:GetAttributeChangedSignal("DeliveryRecord_" .. vault.id):Connect(update)
end
for _, row in ipairs(rows) do
    player:GetAttributeChangedSignal("OwnsPet_" .. row.id):Connect(update)
end
update()
