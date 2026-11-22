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
gui.Parent = player:WaitForChild("PlayerGui")

local open = textItem("TextButton", gui, "Питомцы", 14, palette.panel)
open.AnchorPoint = Vector2.new(0.5, 0)
open.Position = UDim2.new(0.5, 0, 0, 146)
open.Size = UDim2.fromOffset(150, 44)
fill(open, palette.gold, 12)

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 146)
panel.Size = UDim2.new(0.92, 0, 1, -156)
panel.Visible = false
panel.Parent = gui
fill(panel, palette.panel, 16)
Instance.new("UISizeConstraint", panel).MaxSize = Vector2.new(468, 480)

local title = textItem("TextLabel", panel, "Коллекция", 20, palette.text)
title.Position = UDim2.fromOffset(16, 5)
title.Size = UDim2.new(1, -130, 0, 46)
title.TextXAlignment = Enum.TextXAlignment.Left

local close = textItem("TextButton", panel, "Закрыть", 14, palette.text)
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -10, 0, 6)
close.Size = UDim2.fromOffset(90, 44)
fill(close, palette.row, 10)
open.Activated:Connect(function()
    panel.Visible = true
    open.Visible = false
end)
close.Activated:Connect(function()
    panel.Visible = false
    open.Visible = true
end)

local list = Instance.new("ScrollingFrame")
list.Name = "Species"
list.Position = UDim2.fromOffset(12, 58)
list.Size = UDim2.new(1, -24, 1, -70)
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

local trial = textItem("TextLabel", list, "", 13, palette.gold)
trial.Name = "StormTrial"
trial.LayoutOrder = 0
trial.Size = UDim2.new(1, -8, 0, 62)
trial.TextWrapped = true
fill(trial, palette.row, 10)
local trialPadding = Instance.new("UIPadding", trial)
trialPadding.PaddingLeft = UDim.new(0, 10)
trialPadding.PaddingRight = UDim.new(0, 10)

local weekly = textItem("TextLabel", list, "", 13, palette.text)
weekly.Name = "WeeklyBest"
weekly.LayoutOrder = 1
weekly.Size = UDim2.new(1, -8, 0, 46)
weekly.TextWrapped = true
fill(weekly, palette.row, 10)

local round = shared:WaitForChild("Round")
local leaderboardFeed = round:WaitForChild("WeeklyLeaderboard")
local boardButton = textItem("TextButton", list, "Показать топ недели", 13, palette.panel)
boardButton.LayoutOrder = 2
boardButton.Size = UDim2.new(1, -8, 0, 44)
fill(boardButton, palette.gold, 10)
local board = textItem("TextLabel", list, "", 13, palette.text)
board.Name = "WeeklyLeaderboard"
board.LayoutOrder = 3
board.Visible = false
board.Size = UDim2.new(1, -8, 0, 0)
board.AutomaticSize = Enum.AutomaticSize.Y
board.TextWrapped = true
fill(board, palette.row, 10)
local boardPadding = Instance.new("UIPadding", board)
boardPadding.PaddingTop = UDim.new(0, 10)
boardPadding.PaddingBottom = UDim.new(0, 10)

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
    local record = textItem("TextLabel", list, "", 13, palette.gold)
    record.Name = "DeliveryRecord_" .. vault.id
    record.LayoutOrder = order
    record.Size = UDim2.new(1, -8, 0, 32)
    record.TextWrapped = true
    recordLabels[vault] = record
    for _, pet in ipairs({ vault.pets.common, vault.pets.rare }) do
        local row = Instance.new("Frame")
        row.Name = pet.id
        order += 1
        row.LayoutOrder = order
        row.Size = UDim2.new(1, -8, 0, 78)
        row.Parent = list
        fill(row, palette.row, 10)

        local name = textItem("TextLabel", row, pet.name, 15, palette.text)
        name.Position = UDim2.fromOffset(10, 7)
        name.Size = UDim2.new(1, -112, 0, 21)
        name.TextXAlignment = Enum.TextXAlignment.Left

        local commonEggOdds = Rules.RarePetChance["Обычное"]
        local rareEggOdds = Rules.RarePetChance["Редкое"]
        if pet == vault.pets.common then
            commonEggOdds, rareEggOdds = 100 - commonEggOdds, 100 - rareEggOdds
        end
        local condition = string.format("%s\nИз обычного яйца %d%%, редкого %d%%",
            pet.rarity, commonEggOdds, rareEggOdds)
        local details = textItem("TextLabel", row, condition, 12, palette.muted)
        details.Position = UDim2.fromOffset(10, 29)
        details.Size = UDim2.new(1, -112, 0, 42)
        details.TextXAlignment = Enum.TextXAlignment.Left
        details.TextWrapped = true

        local action = textItem("TextButton", row, "", 12, palette.panel)
        action.AnchorPoint = Vector2.new(1, 0.5)
        action.Position = UDim2.new(1, -8, 0.5, 0)
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
    weekly.Text = if time then "Рекорд недели · " .. Rules.deliveryTimeText(time)
        else "Забег недели · вход в лагере"
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
player:GetAttributeChangedSignal("StormTrailUnlocked"):Connect(update)
for vault in pairs(recordLabels) do
    player:GetAttributeChangedSignal("DeliveryRecord_" .. vault.id):Connect(update)
end
for _, row in ipairs(rows) do
    player:GetAttributeChangedSignal("OwnsPet_" .. row.id):Connect(update)
end
update()
