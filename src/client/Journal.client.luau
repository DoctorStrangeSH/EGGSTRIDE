local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Eggstride")
local Rules = require(shared:WaitForChild("Rules"))
local equipPet = shared:WaitForChild("EquipPet")
local breedPet = shared:WaitForChild("BreedPet")
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

local function menuButton(caption, order)
    local button = textItem("TextButton", list, caption, 14, palette.panel)
    button.LayoutOrder = order
    button.Size = UDim2.new(1, -8, 0, 44)
    button.TextWrapped = true
    fill(button, palette.gold, 10)
    return button
end

local nurseryButton = menuButton("Питомник  +", -12)
local biomeButton = menuButton("", -11)
local experiment = menuButton("Проверить пару", -10)
local nurseryInfo = description("Experiment", -9, palette.text)
nurseryInfo.TextXAlignment = Enum.TextXAlignment.Left
local choices = Instance.new("Frame")
choices.Name = "Parents"
choices.LayoutOrder = -8
choices.BackgroundTransparency = 1
choices.Size = UDim2.new(1, -8, 0, 0)
choices.Parent = list
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.5, -3, 0, 44)
grid.CellPadding = UDim2.fromOffset(6, 6)
grid.FillDirectionMaxCells = 2
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = choices
grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    choices.Size = UDim2.new(1, -8, 0, grid.AbsoluteContentSize.Y)
end)

local nurseryExpanded = false
local biomeIndex = 1
local selected = {}
local parentButtons = {}
local tested = {}

local function pairKey(first, second)
    if first > second then
        first, second = second, first
    end
    return first .. ":" .. second
end

local function updateNursery()
    local vault = Rules.Vaults[biomeIndex]
    local first, second = selected[1], selected[2]
    local result = if first and second then tested[pairKey(first.id, second.id)] else nil
    local canExperiment = first ~= nil and second ~= nil and (not result or not result.finished)
    local count = 0
    for _, item in ipairs(parentButtons) do
        local visible = item.biomeIndex == biomeIndex and player:GetAttribute("OwnsPet_" .. item.pet.id) == true
        item.button.Visible = visible
        item.button.BackgroundColor3 = if table.find(selected, item.pet) then palette.mint else palette.muted
        if visible then
            count += 1
        end
    end
    nurseryButton.Text = if nurseryExpanded then "Питомник  −" else "Питомник  +"
    biomeButton.Text = string.format("%s · сменить биом", vault.name)
    experiment.Active = canExperiment
    experiment.Selectable = canExperiment
    experiment.AutoButtonColor = canExperiment
    experiment.BackgroundColor3 = if canExperiment then palette.gold else palette.muted
    local text = if count < 2 then "Вылупи двух разных питомцев из обычных яиц этого биома."
        elseif first and second then first.name .. " + " .. second.name
        elseif first then first.name .. " + выбери второго родителя"
        else "Выбери двух родителей. Неподходящая пара не расходует материалы."
    if result then
        text ..= "\n" .. result.text
    end
    local stock = player:GetAttribute("Material_" .. vault.id)
    nurseryInfo.Text = text .. "\n" .. string.format("%s · %d/%d", vault.material, stock or 0, biomeIndex + 1)
    biomeButton.Visible = nurseryExpanded
    nurseryInfo.Visible = nurseryExpanded
    experiment.Visible = nurseryExpanded
    choices.Visible = nurseryExpanded and count > 0
end

for index, vault in ipairs(Rules.Vaults) do
    for position, pet in ipairs(vault.pets) do
        local button = textItem("TextButton", choices, pet.name, 13, palette.panel)
        button.TextWrapped = true
        button.LayoutOrder = position
        fill(button, palette.muted, 8)
        button.Activated:Connect(function()
            local existing = table.find(selected, pet)
            if existing then
                table.remove(selected, existing)
            elseif #selected < 2 then
                table.insert(selected, pet)
            else
                selected[2] = pet
            end
            updateNursery()
        end)
        table.insert(parentButtons, { pet = pet, button = button, biomeIndex = index })
        player:GetAttributeChangedSignal("OwnsPet_" .. pet.id):Connect(updateNursery)
    end
    player:GetAttributeChangedSignal("Material_" .. vault.id):Connect(updateNursery)
end

nurseryButton.Activated:Connect(function()
    nurseryExpanded = not nurseryExpanded
    updateNursery()
end)
biomeButton.Activated:Connect(function()
    biomeIndex = biomeIndex % #Rules.Vaults + 1
    table.clear(selected)
    updateNursery()
end)

local nextAttemptAt = 0
experiment.Activated:Connect(function()
    local first, second = selected[1], selected[2]
    if not experiment.Active or not first or not second or os.clock() < nextAttemptAt then
        return
    end
    nextAttemptAt = os.clock() + 0.5
    breedPet:FireServer(first.id, second.id)
end)
breedPet.OnClientEvent:Connect(function(firstId, secondId, status, name)
    local key = pairKey(firstId, secondId)
    local message = if status == "found" then "Открытие: " .. name .. ". Пара записана в дневнике."
        elseif status == "known" then "Эта пара уже в дневнике: " .. name
        elseif status == "miss" then "Пара не подошла. Попробуй другую."
        else "Этой паре нужны материалы."
    tested[key] = { text = message, finished = status ~= "materials" }
    updateNursery()
end)
updateNursery()

local progressButton = textItem("TextButton", list, "Статистика и материалы  +", 14, palette.panel)
progressButton.LayoutOrder = -5
progressButton.Size = UDim2.new(1, -8, 0, 44)
fill(progressButton, palette.gold, 10)

local progress = description("BiomeProgress", -4, palette.text)
progress.TextXAlignment = Enum.TextXAlignment.Left
progress.Visible = false

local function updateProgress()
    if not progress.Visible then
        return
    end
    if player:GetAttribute("Deliveries_" .. Rules.Vaults[1].id) == nil then
        progress.Text = "Загружаем статистику…"
        return
    end

    local sections = {}
    for _, vault in ipairs(Rules.Vaults) do
        local deliveries = player:GetAttribute("Deliveries_" .. vault.id) or 0
        local materials = player:GetAttribute("Material_" .. vault.id) or 0
        local record = player:GetAttribute("DeliveryRecord_" .. vault.id)
        local heading = string.format("%s · доставок %d", vault.name, deliveries)
        if record then
            heading ..= " · рекорд " .. Rules.deliveryTimeText(record)
        end
        table.insert(sections, heading .. "\n" .. string.format("%s · %d", vault.material, materials))
    end
    local wins = {}
    for _, prize in ipairs(Rules.Prizes) do
        local count = player:GetAttribute("PrizeWins_" .. prize.id) or 0
        table.insert(wins, string.format("%s · %d", prize.name, count))
    end
    table.insert(sections, "Доставлено призов\n" .. table.concat(wins, "\n"))
    progress.Text = table.concat(sections, "\n\n")
end

progressButton.Activated:Connect(function()
    progress.Visible = not progress.Visible
    progressButton.Text = if progress.Visible then "Статистика и материалы  −" else "Статистика и материалы  +"
    updateProgress()
end)

for _, vault in ipairs(Rules.Vaults) do
    player:GetAttributeChangedSignal("Deliveries_" .. vault.id):Connect(updateProgress)
    player:GetAttributeChangedSignal("Material_" .. vault.id):Connect(updateProgress)
    player:GetAttributeChangedSignal("DeliveryRecord_" .. vault.id):Connect(updateProgress)
end
for _, prize in ipairs(Rules.Prizes) do
    player:GetAttributeChangedSignal("PrizeWins_" .. prize.id):Connect(updateProgress)
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
local collectionGroups = {}
local order = 3

local function addPetRow(group, pet, source, secret)
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

    local details = textItem("TextLabel", copy, source, 12, palette.muted)
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
    local entry = {
        id = pet.id, frame = row, action = action, name = name, details = details,
        pet = pet, secret = secret, source = source, group = group,
    }
    table.insert(rows, entry)
    table.insert(group.rows, entry)
end

local update
for index, vault in ipairs(Rules.Vaults) do
    order += 1
    local group = { rows = {}, expanded = false, name = vault.name }
    group.button = menuButton("", order)
    group.button.Activated:Connect(function()
        group.expanded = not group.expanded
        update()
    end)
    table.insert(collectionGroups, group)
    for _, pet in ipairs(vault.pets) do
        addPetRow(group, pet, "Обычное яйцо", false)
    end
    for _, pet in ipairs(Rules.Prizes[index].pets) do
        addPetRow(group, pet, Rules.Prizes[index].name, true)
    end
    for _, pet in ipairs(Rules.Offspring[index]) do
        addPetRow(group, pet, "Питомник", true)
    end
end

update = function()
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
    local count = 0
    local groupCounts = {}
    for _, row in ipairs(rows) do
        local owned = player:GetAttribute("OwnsPet_" .. row.id) == true
        local selected = owned and equipped == row.id
        if owned then
            count += 1
            groupCounts[row.group] = (groupCounts[row.group] or 0) + 1
        end
        row.frame.Visible = row.group.expanded
        row.name.Text = if owned then row.pet.name .. " · " .. row.pet.rarity
            elseif row.secret then "Неизвестный питомец" else row.pet.name
        local recipe = player:GetAttribute("Recipe_" .. row.id)
        row.details.Text = if recipe then "Скрестить: " .. recipe else row.source
        row.action.Text = if selected then "Спутник" elseif owned then "Выбрать" else "Не открыт"
        row.action.BackgroundColor3 = if selected then palette.mint elseif owned then palette.gold else palette.muted
        row.action.Active = owned and not selected
        row.action.Selectable = owned and not selected
        row.action.AutoButtonColor = owned and not selected
    end
    for _, group in ipairs(collectionGroups) do
        group.button.Text = string.format("%s · %d/%d  %s", group.name, groupCounts[group] or 0,
            #group.rows, if group.expanded then "−" else "+")
    end
    open.Text = string.format("Питомцы %d/%d", count, #rows)
    title.Text = string.format("Коллекция %d/%d", count, #rows)
end

player:GetAttributeChangedSignal("EquippedPetId"):Connect(update)
player:GetAttributeChangedSignal("WeeklyBest"):Connect(update)
player:GetAttributeChangedSignal("WeeklyRewardClaimed"):Connect(update)
player:GetAttributeChangedSignal("StormTrailUnlocked"):Connect(update)
for _, row in ipairs(rows) do
    player:GetAttributeChangedSignal("OwnsPet_" .. row.id):Connect(update)
    if row.source == "Питомник" then
        player:GetAttributeChangedSignal("Recipe_" .. row.id):Connect(update)
    end
end
update()
