local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Eggstride")
local Rules = require(shared:WaitForChild("Rules"))
local equipPet = shared:WaitForChild("EquipPet")
local breedPet = shared:WaitForChild("BreedPet")
local mutatePet = shared:WaitForChild("MutatePet")
local claimSeason = shared:WaitForChild("ClaimSeasonReward")
local seasonPass = shared:WaitForChild("SeasonPass")
local cosmeticShop = shared:WaitForChild("CosmeticShop")
local HatchEffects = require(script.Parent.HatchEffects)
local CampThemes = require(script.Parent.CampThemes)
local locale = require(script.Parent.InterfaceLanguage)
local Locale = require(shared:WaitForChild("Locale"))
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
local open = textItem("TextButton", header, locale.text("Питомцы"), 13, palette.panel)
open.AutoLocalize = false
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

local previewCamp = CampThemes.connect(player, Rules)

local function nearCamp()
    local scene = workspace:FindFirstChild("EggstrideWorld")
    local camp = scene and scene:FindFirstChild("Camp")
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return camp and root and player:GetAttribute("WeeklyStartsAt") == nil and (root.Position - camp.Position).Magnitude <= 30
end

local function addCosmetics(caption, firstOrder, items, equippedAttribute)
    local shopButton = menuButton(caption .. "  +", firstOrder)
    local shopExpanded = false
    local shopCards = {}
    for index, item in ipairs(items) do
        local isTrail = item.slot == "trail"
        local isCamp = item.slot == "camp"
        local order = shopButton.LayoutOrder + 1 + (index - 1) * 3
        local heading = description("CosmeticName_" .. item.id, order, palette.text)
        heading.Text = if isCamp then item.name .. "\n" .. item.description else item.name

        local swatch = Instance.new("Frame")
        swatch.LayoutOrder = order + 1
        swatch.Size = UDim2.new(1, -8, 0, if isCamp then 12 elseif isTrail then 8 else 40)
        swatch.BackgroundColor3 = if isTrail or isCamp then Color3.new(1, 1, 1) else palette.row
        swatch.Parent = list
        Instance.new("UICorner", swatch).CornerRadius = UDim.new(0, 8)
        if isTrail or isCamp then
            local gradient = Instance.new("UIGradient")
            gradient.Color = ColorSequence.new(Color3.fromRGB(table.unpack(item.first)), Color3.fromRGB(table.unpack(item.last)))
            gradient.Parent = swatch
        end

        local buttons = Instance.new("Frame")
        buttons.LayoutOrder = order + 2
        buttons.BackgroundTransparency = 1
        buttons.Size = UDim2.new(1, -8, 0, 44)
        buttons.Parent = list

        local try = textItem("TextButton", buttons, if isTrail or isCamp then "Примерить · 12 с" else "Посмотреть", 13, palette.panel)
        try.Size = UDim2.new(0.44, -3, 1, 0)
        try.TextWrapped = true
        fill(try, palette.mint, 10)
        try.Activated:Connect(function()
            if isTrail then
                cosmeticShop:FireServer("try", item.id)
                scrim.Visible = false
                updateLauncher()
            elseif isCamp then
                if not nearCamp() then
                    try.Text = "Вернись в лагерь"
                    task.delay(1.5, function()
                        try.Text = "Примерить · 12 с"
                    end)
                    return
                end
                previewCamp(item)
                scrim.Visible = false
                updateLauncher()
            else
                HatchEffects.play(swatch, item, player:GetAttribute("ReduceCardMotion") == true)
            end
        end)

        local action = textItem("TextButton", buttons, "", 13, palette.panel)
        action.Position = UDim2.new(0.44, 3, 0, 0)
        action.Size = UDim2.new(0.56, -3, 1, 0)
        action.TextWrapped = true
        fill(action, palette.gold, 10)

        local price, productChecked, fetchingPrice, offsale
        local statusAttribute = "CosmeticStatus_" .. item.id
        local function updateCard()
            heading.Visible = shopExpanded
            swatch.Visible = shopExpanded
            if not shopExpanded and not isTrail then
                HatchEffects.clear(swatch)
            end
            buttons.Visible = shopExpanded

            local status = player:GetAttribute(statusAttribute)
            local selected = player:GetAttribute(equippedAttribute) == item.id
            local passId = cosmeticShop:GetAttribute("Pass_" .. item.id)
            if shopExpanded and status == "locked" and passId and not (productChecked or fetchingPrice) then
                fetchingPrice = true
                task.defer(function()
                    local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, passId, Enum.InfoType.GamePass)
                    if ok then
                        price = info.PriceInRobux
                        offsale = info.IsForSale == false
                    end
                    productChecked = true
                    fetchingPrice = false
                    updateCard()
                end)
            end
            local livePurchase = status == "locked" and productChecked and not offsale
            local enabled = status == "preview" or status == "owned" or status == "error" or livePurchase
            action.Text = if status == "owned" then (if selected then "Снять" elseif isTrail then "Надеть" elseif isCamp then "Применить" else "Выбрать")
                elseif status == "preview" then "Тестовая покупка"
                elseif status == "locked" and offsale then "Вне продажи"
                elseif livePurchase then (if price then "Купить · " .. price .. " R$" else "Купить за Robux")
                elseif status == "prompting" then "Окно Roblox…"
                elseif status == "error" then "Повторить проверку"
                elseif status == "unavailable" then "Покупка недоступна"
                else "Загрузка…"
            action.Active = enabled
            action.Selectable = enabled
            action.AutoButtonColor = enabled
            action.BackgroundColor3 = if enabled then palette.gold else palette.muted
        end

        action.Activated:Connect(function()
            if action.Active then
                local status = player:GetAttribute(statusAttribute)
                if status == "owned" then
                    local selected = player:GetAttribute(equippedAttribute) == item.id
                    cosmeticShop:FireServer(if selected then "unequip" else "equip", item.id)
                else
                    cosmeticShop:FireServer("buy", item.id)
                end
            end
        end)
        player:GetAttributeChangedSignal(statusAttribute):Connect(updateCard)
        player:GetAttributeChangedSignal(equippedAttribute):Connect(updateCard)
        cosmeticShop:GetAttributeChangedSignal("Pass_" .. item.id):Connect(updateCard)
        table.insert(shopCards, updateCard)
        updateCard()
    end

    shopButton.Activated:Connect(function()
        shopExpanded = not shopExpanded
        shopButton.Text = caption .. (if shopExpanded then "  −" else "  +")
        for _, updateCard in ipairs(shopCards) do
            updateCard()
        end
    end)
end

addCosmetics("Оформление лагеря", -70, Rules.CampThemes, "EquippedCampTheme")
addCosmetics("Магазин следов", -60, Rules.Trails, "EquippedTrail")
addCosmetics("Эффекты вылупления", -50, Rules.HatchEffects, "EquippedHatchEffect")

local season = Rules.Season
local seasonButton = menuButton("Сезон «" .. season.name .. "»  +", -40)
local seasonInfo = description("SeasonProgress", -39, palette.text)
seasonInfo.TextXAlignment = Enum.TextXAlignment.Left
local seasonExpanded = false
local function addSeasonRewards(rewards, firstOrder, premium)
    local buttons = {}
    for index in ipairs(rewards) do
        local action = menuButton("", firstOrder + index - 1)
        buttons[index] = action
        action.Activated:Connect(function()
            if action.Active then
                claimSeason:FireServer(index, premium)
            end
        end)
    end
    return buttons
end

local rewardButtons = addSeasonRewards(season.rewards, -38, false)
local premiumInfo = description("PremiumTrack", -33, palette.text)
premiumInfo.TextXAlignment = Enum.TextXAlignment.Left
premiumInfo.Text = "Косметическая дорожка\nТри расцветки светляка за тот же сезонный опыт."
local premiumAction = menuButton("", -32)
local premiumButtons = addSeasonRewards(season.premiumRewards, -31, true)
premiumAction.Activated:Connect(function()
    if premiumAction.Active then
        seasonPass:FireServer()
    end
end)

local function updateRewardButtons(rewards, buttons, xp, prefix, access)
    for index, reward in ipairs(rewards) do
        local action = buttons[index]
        local claimed = player:GetAttribute(prefix .. index) == true
        local available = xp ~= nil and xp >= reward.xp and not claimed and access
        local status = if claimed then "Получено" elseif available then "Забрать"
            elseif not access then reward.xp .. " XP + пропуск" else reward.xp .. " XP"
        action.Text = string.format("%s · %s", reward.label, status)
        action.Visible = seasonExpanded
        action.Active = available
        action.Selectable = available
        action.AutoButtonColor = available
        action.BackgroundColor3 = if claimed then palette.mint elseif available then palette.gold else palette.muted
    end
end

local function updateSeason()
    local xp = player:GetAttribute("SeasonXP")
    local maximum = season.rewards[#season.rewards].xp
    seasonButton.Text = string.format("Сезон «%s»  %s", season.name, if seasonExpanded then "−" else "+")
    seasonInfo.Visible = seasonExpanded
    local lines = {}
    if xp ~= nil then
        table.insert(lines, string.format("Опыт сезона · %d/%d", xp, maximum))
        table.insert(lines, "Задания обновляются по понедельникам в 00:00 UTC.")
        for _, quest in ipairs(season.quests) do
            local count = player:GetAttribute("SeasonQuest_" .. quest.id) or 0
            table.insert(lines, string.format("%s · %d/%d · +%d XP", quest.label, count, quest.goal, quest.xp))
        end
        local times = {}
        for _, vault in ipairs(Rules.Vaults) do
            local best = player:GetAttribute("SeasonDeliveryBest_" .. vault.id)
            if best then
                table.insert(times, vault.name .. " · " .. Locale.deliveryTime("ru", best))
            end
        end
        table.insert(lines, if #times > 0 then "Лучшие доставки недели\n" .. table.concat(times, "\n")
            else "Первая доставка в биоме задаёт время для сравнения.")
    else
        table.insert(lines, "Загружаем прогресс сезона…")
    end
    seasonInfo.Text = table.concat(lines, "\n\n")
    local status = player:GetAttribute("SeasonPremiumStatus")
    local access = status == "owned" or status == "previewOwned"
    local actionable = status == "preview" or status == "locked" or status == "error"
    premiumInfo.Visible = seasonExpanded
    premiumAction.Visible = seasonExpanded
    premiumAction.Text = if status == "preview" then "Включить тестовый пропуск"
        elseif status == "previewOwned" then "Тестовый пропуск активен"
        elseif status == "owned" then "Пропуск активен"
        elseif status == "locked" then "Купить пропуск за Robux"
        elseif status == "error" then "Повторить проверку пропуска"
        elseif status == "unavailable" then "Пропуск пока недоступен"
        elseif status == "prompting" then "Покупка в окне Roblox…"
        else "Проверяем пропуск…"
    premiumAction.Active = actionable
    premiumAction.Selectable = actionable
    premiumAction.AutoButtonColor = actionable
    premiumAction.BackgroundColor3 = if access then palette.mint elseif actionable then palette.gold else palette.muted
    updateRewardButtons(season.rewards, rewardButtons, xp, "SeasonClaimed_", true)
    updateRewardButtons(season.premiumRewards, premiumButtons, xp, "SeasonPremiumClaimed_", access)
end

seasonButton.Activated:Connect(function()
    seasonExpanded = not seasonExpanded
    updateSeason()
end)
player:GetAttributeChangedSignal("SeasonXP"):Connect(updateSeason)
for _, quest in ipairs(season.quests) do
    player:GetAttributeChangedSignal("SeasonQuest_" .. quest.id):Connect(updateSeason)
end
for _, vault in ipairs(Rules.Vaults) do
    player:GetAttributeChangedSignal("SeasonDeliveryBest_" .. vault.id):Connect(updateSeason)
end
for index in ipairs(season.rewards) do
    player:GetAttributeChangedSignal("SeasonClaimed_" .. index):Connect(updateSeason)
end
player:GetAttributeChangedSignal("SeasonPremiumStatus"):Connect(updateSeason)
for index in ipairs(season.premiumRewards) do
    player:GetAttributeChangedSignal("SeasonPremiumClaimed_" .. index):Connect(updateSeason)
end
updateSeason()

local mutationsButton = menuButton("Мутации  +", -20)
local mutationCards = {}
local mutationsExpanded = false

for index, mutation in ipairs(Rules.Mutations) do
    local order = mutationsButton.LayoutOrder + index * 2
    local info = description("Mutation_" .. mutation.pet.id, order - 1, palette.text)
    info.TextXAlignment = Enum.TextXAlignment.Left
    local action = menuButton("", order)
    info.Visible = false
    action.Visible = false
    table.insert(mutationCards, { info = info, action = action })

    local stockAttribute = "Catalyst_" .. mutation.vault.id
    local parentAttribute = "OwnsPet_" .. mutation.parent.id
    local ownedAttribute = "OwnsPet_" .. mutation.pet.id
    local function updateMutation()
        local stock = player:GetAttribute(stockAttribute)
        local owned = player:GetAttribute(ownedAttribute) == true
        local hasParent = player:GetAttribute(parentAttribute) == true
        local canMutate = not owned and hasParent and stock ~= nil and stock >= mutation.cost
        info.Text = mutation.pet.name .. "\n" .. mutation.appearance
        if not owned then
            info.Text ..= "\n" .. mutation.route .. "\n"
                .. string.format("Катализаторы · %d/%d", stock or 0, mutation.cost)
        end
        action.Text = if owned then "В коллекции"
            elseif not hasParent then "Нужен питомец «" .. mutation.parent.name .. "»"
            elseif not canMutate then "Нужны катализаторы"
            else "Открыть форму"
        action.Active = canMutate
        action.Selectable = canMutate
        action.AutoButtonColor = canMutate
        action.BackgroundColor3 = if owned then palette.mint elseif canMutate then palette.gold else palette.muted
    end

    for _, attribute in ipairs({ stockAttribute, parentAttribute, ownedAttribute }) do
        player:GetAttributeChangedSignal(attribute):Connect(updateMutation)
    end
    action.Activated:Connect(function()
        if action.Active then
            mutatePet:FireServer(mutation.pet.id)
        end
    end)
    updateMutation()
end

mutationsButton.Activated:Connect(function()
    mutationsExpanded = not mutationsExpanded
    mutationsButton.Text = if mutationsExpanded then "Мутации  −" else "Мутации  +"
    for _, card in ipairs(mutationCards) do
        card.info.Visible = mutationsExpanded
        card.action.Visible = mutationsExpanded
    end
end)

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
            heading ..= " · рекорд " .. Locale.deliveryTime("ru", record)
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
    addPetRow(group, Rules.Mutations[index].pet, "Мутация", false)
end

order += 1
local seasonGroup = { rows = {}, expanded = false, name = "Сезонные питомцы" }
seasonGroup.button = menuButton("", order)
seasonGroup.button.Activated:Connect(function()
    seasonGroup.expanded = not seasonGroup.expanded
    update()
end)
table.insert(collectionGroups, seasonGroup)
for _, pet in ipairs(Rules.SeasonPets) do
    addPetRow(seasonGroup, pet, "Награда сезона", false)
end

update = function()
    local equipped = player:GetAttribute("EquippedPetId")
    local time = player:GetAttribute("WeeklyBest")
    local heading = if time then "Рекорд недели · " .. Locale.deliveryTime("ru", time)
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
