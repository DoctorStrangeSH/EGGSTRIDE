local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Eggstride")
local Rules = require(shared:WaitForChild("Rules"))
local round = shared:WaitForChild("Round")
local RunFeedback = require(script.Parent:WaitForChild("RunFeedback"))
local gateTarget = round:WaitForChild("Gate")
local eggTarget = round:WaitForChild("FirstEgg")
local hatchTarget = round:WaitForChild("Hatch")

local colors = {
    ink = Color3.fromRGB(37, 34, 65),
    white = Color3.fromRGB(255, 251, 231),
    gold = Color3.fromRGB(255, 209, 117),
    mint = Color3.fromRGB(163, 255, 201),
}

local gui = Instance.new("ScreenGui")
gui.Name = "EggstrideHud"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")
local updateFeedback = RunFeedback.connect(gui, shared:WaitForChild("RunFeedback"), Rules)

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 9)
panel.Size = UDim2.new(0.94, 0, 0, 130)
panel.BackgroundColor3 = colors.ink
panel.BackgroundTransparency = 0.06
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
Instance.new("UISizeConstraint", panel).MaxSize = Vector2.new(420, 130)

local function label(name, y, height, size, color)
    local item = Instance.new("TextLabel")
    item.Name = name
    item.Position = UDim2.new(0, 12, 0, y)
    item.Size = UDim2.new(1, -24, 0, height)
    item.BackgroundTransparency = 1
    item.Font = Enum.Font.GothamBold
    item.Text = ""
    item.TextSize = size
    item.TextColor3 = color
    item.TextWrapped = true
    item.Parent = panel
    return item
end

local timer = label("Timer", 5, 26, 17, colors.gold)
local stats = label("Stats", 30, 22, 15, colors.white)
local pet = label("Pet", 53, 19, 13, colors.mint)
local objective = label("Objective", 74, 22, 13, colors.gold)
local notice = label("Notice", 94, 32, 12, colors.white)

local runOpen = false
local guide = Instance.new("Highlight")
guide.Name = "EggstrideFirstRun"
guide.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
guide.FillColor = colors.gold
guide.FillTransparency = 0.82
guide.OutlineColor = colors.gold
guide.Enabled = false
guide.Parent = workspace

local function update()
    local egg = player:GetAttribute("EggName")
    local ability = Rules.Abilities[player:GetAttribute("EggAbility")]
    local best = player:GetAttribute("EquippedPet")
    local tier = player:GetAttribute("SpeedTier") or 1
    local cost = Rules.UpgradeCosts[tier]
    stats.Text = string.format("Монеты %d  ·  Скорость %d/5", player:GetAttribute("Coins") or 0, tier)
    pet.Text = if egg and egg ~= "" then "Несёшь яйцо: " .. egg
        elseif best and best ~= "" then "Питомец: " .. best
        else "Питомец появится после вылупления"
    objective.Text = if ability then ability.name .. " · " .. ability.hint
        elseif egg and egg ~= "" then "Цель: успей к инкубатору"
        elseif player:GetAttribute("Delivered") then "Яйцо спасено · жди следующего забега"
        elseif cost then "Следующая тренировка: " .. cost .. " монет"
        else "Выбирай остров и возвращайся до закрытия"
    local step = player:GetAttribute("OnboardingStep")
    local target
    if (step == 1 or step == 2) and not player:GetAttribute("Delivered") then
        if egg and egg ~= "" then
            objective.Text = "Донеси яйцо до подсвеченного инкубатора"
            target = hatchTarget.Value
        elseif runOpen then
            objective.Text = "Забери яйцо на Луговом острове"
            target = eggTarget.Value
        else
            objective.Text = "Подойди к воротам и дождись старта"
            target = gateTarget.Value
        end
    elseif step == 3 and (not egg or egg == "") then
        objective.Text = "Открой «Питомцы» и попробуй новый забег"
    end
    local weeklyGoal = player:GetAttribute("WeeklyGoal")
    if weeklyGoal then
        objective.Text = weeklyGoal
        stats.Text = "Забег недели · скорость " .. Rules.Weekly.tier .. " для всех"
        pet.Text = "Контрольные точки проходятся по порядку"
        target = nil
    end
    guide.Adornee = target
    guide.Enabled = target ~= nil
    local wind = player:GetAttribute("WindEffect")
    notice.Text = wind or player:GetAttribute("Notice") or ""
end

for _, name in ipairs({ "OnboardingStep", "Coins", "SpeedTier", "EggName", "EggAbility", "EquippedPet", "Delivered", "Notice", "WindEffect", "WeeklyGoal" }) do
    player:GetAttributeChangedSignal(name):Connect(update)
end
for _, target in ipairs({ gateTarget, eggTarget, hatchTarget }) do
    target:GetPropertyChangedSignal("Value"):Connect(update)
end
update()

while true do
    local start = round:GetAttribute("StartedAt")
    if start then
        local open, left = Rules.clock(math.max(0, workspace:GetServerTimeNow() - start))
        if open ~= runOpen then
            runOpen = open
            update()
        end
        local closing = open and left <= 5
        local phase = if closing then "ВОРОТА ЗАКРЫВАЮТСЯ" elseif open then "ЗАБЕГ" else "ПОДГОТОВКА"
        timer.Text = string.format("%s  ·  %02d сек", phase, left)
        timer.TextColor3 = if closing then Color3.fromRGB(255, 147, 137) else colors.gold
        local egg = player:GetAttribute("EggName")
        updateFeedback(open, left, egg ~= nil and egg ~= "", player:GetAttribute("WeeklyEndsAt") ~= nil)
    end
    local endsAt = player:GetAttribute("WeeklyEndsAt")
    if endsAt then
        local left = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
        timer.Text = string.format("ЗАБЕГ НЕДЕЛИ  ·  %02d сек", left)
        timer.TextColor3 = if left <= 5 then Color3.fromRGB(255, 147, 137) else colors.gold
    end
    task.wait(0.2)
end
