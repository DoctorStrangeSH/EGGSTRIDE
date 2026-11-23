local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Eggstride")
local Rules = require(shared:WaitForChild("Rules"))
local locale = require(script.Parent.InterfaceLanguage)
local text = locale.text
local round = shared:WaitForChild("Round")
local cancelWeekly = shared:WaitForChild("CancelWeekly")
local RunFeedback = require(script.Parent:WaitForChild("RunFeedback"))
local gateTarget = round:WaitForChild("Gate")
local eggTarget = round:WaitForChild("FirstEgg")
local hatchTarget = round:WaitForChild("Hatch")
local trainingTarget = round:WaitForChild("Training")
local abilityTargets = {
    vine = round:WaitForChild("Vine"),
    relay = round:WaitForChild("Relay"),
}
local weeklyTargets = {}
for _, point in ipairs(Rules.Weekly.order) do
    if not weeklyTargets[point] then
        weeklyTargets[point] = round:WaitForChild("Weekly" .. point)
    end
end

local colors = {
    ink = Color3.fromRGB(37, 34, 65),
    button = Color3.fromRGB(55, 51, 86),
    white = Color3.fromRGB(255, 251, 231),
    gold = Color3.fromRGB(255, 209, 117),
    mint = Color3.fromRGB(163, 255, 201),
}

local gui = Instance.new("ScreenGui")
gui.Name = "EggstrideHud"
gui.AutoLocalize = false
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

local panel = Instance.new("Frame")
panel.Name = "Status"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 6)
panel.Size = UDim2.new(1, -16, 0, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = colors.ink
panel.BackgroundTransparency = 0.12
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
Instance.new("UISizeConstraint", panel).MaxSize = Vector2.new(364, math.huge)

local padding = Instance.new("UIPadding", panel)
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.PaddingTop = UDim.new(0, 4)
padding.PaddingBottom = UDim.new(0, 6)
local stack = Instance.new("UIListLayout", panel)
stack.SortOrder = Enum.SortOrder.LayoutOrder
stack.Padding = UDim.new(0, 2)

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundTransparency = 1
header.Parent = panel

local function label(parent, name, order, size, color)
    local item = Instance.new("TextLabel")
    item.Name = name
    item.LayoutOrder = order
    item.Size = UDim2.new(1, 0, 0, 0)
    item.AutomaticSize = Enum.AutomaticSize.Y
    item.BackgroundTransparency = 1
    item.Font = Enum.Font.GothamMedium
    item.Text = ""
    item.TextSize = size
    item.TextColor3 = color
    item.TextWrapped = true
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.Parent = parent
    return item
end

local timer = label(header, "Timer", 0, 15, colors.gold)
timer.Size = UDim2.new(1, -110, 1, 0)
timer.AutomaticSize = Enum.AutomaticSize.None
timer.Font = Enum.Font.GothamBold
local stats = label(panel, "Stats", 1, 13, colors.white)
local objective = label(panel, "Objective", 2, 13, colors.mint)
local notice = label(panel, "Notice", 3, 12, colors.white)

gui.Parent = player:WaitForChild("PlayerGui")
local updateFeedback = RunFeedback.connect(gui, shared:WaitForChild("RunFeedback"), Rules, player, locale)

local runOpen = false
local guide = Instance.new("Highlight")
guide.Name = "EggstrideObjective"
guide.DepthMode = Enum.HighlightDepthMode.Occluded
guide.FillColor = colors.gold
guide.FillTransparency = 0.82
guide.OutlineColor = colors.gold
guide.Enabled = false
guide.Parent = workspace

local waypoint = Instance.new("BillboardGui")
waypoint.Name = "WeeklyWaypoint"
waypoint.AlwaysOnTop = false
waypoint.MaxDistance = 56
waypoint.LightInfluence = 0
waypoint.Size = UDim2.fromOffset(24, 20)
waypoint.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
waypoint.Enabled = false
waypoint.Parent = gui

local waypointText = Instance.new("TextLabel")
waypointText.Size = UDim2.fromScale(1, 1)
waypointText.BackgroundColor3 = colors.gold
waypointText.TextColor3 = colors.ink
waypointText.Font = Enum.Font.GothamBold
waypointText.TextSize = 12
waypointText.Text = "▼"
waypointText.Parent = waypoint
Instance.new("UICorner", waypointText).CornerRadius = UDim.new(0, 6)

local exitControls = Instance.new("Frame")
exitControls.Name = "WeeklyExit"
exitControls.LayoutOrder = 4
exitControls.Size = UDim2.new(1, 0, 0, 44)
exitControls.BackgroundTransparency = 1
exitControls.Visible = false
exitControls.Parent = panel

local function exitButton(parent, name, caption, position, size, background, foreground)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Text = text(caption)
    button.Position = position
    button.Size = size
    button.TextWrapped = true
    button.Font = Enum.Font.GothamBold
    button.TextSize = 13
    button.BackgroundColor3 = background
    button.TextColor3 = foreground
    button.Parent = parent
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)
    return button
end

local exit = exitButton(header, "Exit", "Выйти", UDim2.fromScale(1, 0),
    UDim2.fromOffset(102, 44), colors.button, colors.white)
exit.AnchorPoint = Vector2.new(1, 0)
exit.Visible = false
local confirm = exitButton(exitControls, "ConfirmExit", "Выйти в лагерь", UDim2.new(),
    UDim2.new(0.5, -3, 1, 0), colors.gold, colors.ink)
local resume = exitButton(exitControls, "ResumeRun", "Продолжить", UDim2.new(0.5, 3, 0, 0),
    UDim2.new(0.5, -3, 1, 0), colors.button, colors.white)
local exitAttempt

local function showExitConfirmation(shown)
    exit.Visible = not shown and player:GetAttribute("WeeklyStartsAt") ~= nil
    exitControls.Visible = shown
end

exit.Activated:Connect(function()
    exitAttempt = player:GetAttribute("WeeklyStartsAt")
    showExitConfirmation(exitAttempt ~= nil)
end)
resume.Activated:Connect(function()
    exitAttempt = nil
    showExitConfirmation(false)
end)
confirm.Activated:Connect(function()
    if exitAttempt and exitAttempt == player:GetAttribute("WeeklyStartsAt") then
        cancelWeekly:FireServer(exitAttempt)
    end
    exitAttempt = nil
    showExitConfirmation(false)
end)

local function updateNotice()
    local message
    if player:GetAttribute("WeeklyStartsAt") then
        message = player:GetAttribute("WeeklySplitText")
    else
        message = player:GetAttribute("WindEffect")
        local expiresAt = player:GetAttribute("NoticeUntil")
        if not message and (not expiresAt or expiresAt > workspace:GetServerTimeNow()) then
            message = player:GetAttribute("Notice")
        end
    end
    notice.Text = message or ""
    notice.Visible = notice.Text ~= ""
end

local function updateGuide()
    local target = guide.Adornee
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local nearby = target ~= nil and root ~= nil and (root.Position - target.Position).Magnitude <= 56
    guide.Enabled = nearby
    waypoint.Enabled = nearby and waypoint.Adornee ~= nil
end

local onboardingTargets = {
    firstEgg = eggTarget, nextEgg = eggTarget, train = trainingTarget, gate = gateTarget,
}
local onboardingLabels = {
    firstEgg = text("Забери яйцо на Луговом острове"),
    nextEgg = text("Возьми ещё одно луговое яйцо"),
    train = text("Купи скорость за %d монет", Rules.UpgradeCosts[1]),
    gate = text("Дождись старта у ворот"),
    collection = text("Открой коллекцию до следующего забега"),
}

local function update()
    local carrying = player:GetAttribute("CarryingEgg") == true
    local delivered = player:GetAttribute("Delivered") == true
    local abilityId = player:GetAttribute("EggAbility")
    local ability = Rules.Abilities[abilityId]
    local tier = player:GetAttribute("SpeedTier") or 1
    stats.Text = text("Монеты %d  ·  Скорость %d/%d", player:GetAttribute("Coins") or 0, tier, #Rules.Speeds)
    local prizeStatus = if Rules.canUseVault(tier, Rules.Vaults[3]) then round:GetAttribute("PrizeStatus_storm_" .. locale.language)
        elseif Rules.canUseVault(tier, Rules.Vaults[2]) then round:GetAttribute("PrizeStatus_amber_" .. locale.language)
        else round:GetAttribute("PrizeStatus_meadow_" .. locale.language) or text("Луговое яйцо доступно каждому")
    objective.Text = if carrying and ability then text(ability.hint)
        elseif carrying then text("К инкубатору")
        elseif delivered then text("Яйцо спасено")
        else prizeStatus or ""
    local target
    if carrying then
        local shortcut = abilityTargets[abilityId]
        target = if shortcut then shortcut.Value else hatchTarget.Value
    else
        local objectiveKey = Rules.onboardingObjective(player:GetAttribute("OnboardingStep"), runOpen, delivered, tier)
        if objectiveKey then
            objective.Text = onboardingLabels[objectiveKey]
            local marker = onboardingTargets[objectiveKey]
            target = marker and marker.Value
        end
    end
    local weeklyStart = player:GetAttribute("WeeklyStartsAt")
    if exitAttempt and exitAttempt ~= weeklyStart then
        exitAttempt = nil
    end
    showExitConfirmation(exitAttempt ~= nil)
    local weeklyStep = player:GetAttribute("WeeklyStep")
    local weeklyPoint = weeklyTargets[Rules.Weekly.order[weeklyStep]]
    if weeklyPoint then
        objective.Text = text(Rules.Weekly.labels[weeklyStep])
        stats.Text = text("Этап %d/%d", weeklyStep, #Rules.Weekly.order)
        target = weeklyPoint.Value
    elseif weeklyStart then
        stats.Text = text("Скорость %d у всех", Rules.Weekly.tier)
        objective.Text = text("Пройди метки и верни яйцо")
        target = nil
    end
    waypoint.Adornee = if weeklyPoint then target else nil
    guide.Adornee = target
    objective.Visible = objective.Text ~= ""
    updateGuide()
    updateNotice()
end

for _, name in ipairs({ "OnboardingStep", "Coins", "SpeedTier", "CarryingEgg", "EggAbility", "Delivered", "WeeklyStep", "WeeklyStartsAt" }) do
    player:GetAttributeChangedSignal(name):Connect(update)
end
for _, name in ipairs({ "Notice", "NoticeUntil", "WindEffect", "WeeklySplitText" }) do
    player:GetAttributeChangedSignal(name):Connect(updateNotice)
end
for _, definition in ipairs(Rules.Prizes) do
    round:GetAttributeChangedSignal("PrizeStatus_" .. definition.id .. "_" .. locale.language):Connect(update)
end
for _, target in ipairs({ gateTarget, eggTarget, hatchTarget, trainingTarget, abilityTargets.vine, abilityTargets.relay }) do
    target:GetPropertyChangedSignal("Value"):Connect(update)
end
for _, target in pairs(weeklyTargets) do
    target:GetPropertyChangedSignal("Value"):Connect(update)
end
update()

while true do
    local weeklyStart = player:GetAttribute("WeeklyStartsAt")
    local start = round:GetAttribute("StartedAt")
    if start then
        local open, left = Rules.clock(math.max(0, workspace:GetServerTimeNow() - start))
        if open ~= runOpen then
            runOpen = open
            update()
        end
        local closing = open and left <= 5
        local phase = if closing then "Ворота закроются" elseif open then "Забег" else "Подготовка"
        timer.Text = text("%s  ·  %02d сек", text(phase), left)
        timer.TextColor3 = if closing then Color3.fromRGB(255, 147, 137) else colors.gold
        updateFeedback(open, left, player:GetAttribute("CarryingEgg") == true, weeklyStart ~= nil)
    end
    local endsAt = player:GetAttribute("WeeklyEndsAt")
    if endsAt then
        local left = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
        timer.Text = text("%s  ·  %02d сек", text("Забег недели"), left)
        timer.TextColor3 = if left <= 5 then Color3.fromRGB(255, 147, 137) else colors.gold
    elseif weeklyStart then
        local left = math.max(1, math.ceil(weeklyStart - workspace:GetServerTimeNow()))
        timer.Text = text("Старт через %d", left)
        timer.TextColor3 = colors.gold
    end
    updateGuide()
    updateNotice()
    task.wait(0.2)
end
