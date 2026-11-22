local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Eggstride")
local Rules = require(shared:WaitForChild("Rules"))
local equipPet = shared:WaitForChild("EquipPet")

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

local rows = {}

for _, vault in ipairs(Rules.Vaults) do
    for _, pet in ipairs({ vault.pets.common, vault.pets.rare }) do
        local row = Instance.new("Frame")
        row.Name = pet.id
        row.LayoutOrder = #rows + 1
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
        local condition = string.format("%s · %s\nИз обычного яйца %d%%, редкого %d%%",
            vault.name, pet.rarity, commonEggOdds, rareEggOdds)
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
for _, row in ipairs(rows) do
    player:GetAttributeChangedSignal("OwnsPet_" .. row.id):Connect(update)
end
update()
