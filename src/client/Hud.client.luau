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
    vineExit = round:WaitForChild("VineExit"),
    vineBypass = round:WaitForChild("VineBypass"),
    relay = round:WaitForChild("Relay"),
    windEntrance = round:WaitForChild("WindEntrance"),
    windExit = round:WaitForChild("WindExit"),
}
local weeklyTargets = {}
for _, point in ipairs(Rules.Weekly.order) do
    if not weeklyTargets[point] then
        weeklyTargets[point] = round:WaitForChild("Weekly" .. point)
    end
end

local UiKit = require(script.Parent:WaitForChild("UiKit"))
local palette = UiKit.Colors
local colors = {
    ink = palette.ink,
    button = palette.inkSoft,
    white = palette.cream,
    gold = palette.gold,
    mint = palette.mint,
}

local gui = Instance.new("ScreenGui")
gui.Name = "EggstrideHud"
gui.AutoLocalize = false
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

-- Top column: status card, then alert pills below it. Scaled as one block.
local top = Instance.new("Frame")
top.Name = "Top"
top.AnchorPoint = Vector2.new(0.5, 0)
top.Position = UDim2.new(0.5, 0, 0, 6)
top.Size = UDim2.new(1, -16, 0, 0)
top.AutomaticSize = Enum.AutomaticSize.Y
top.BackgroundTransparency = 1
top.Parent = gui
Instance.new("UISizeConstraint", top).MaxSize = Vector2.new(380, math.huge)
UiKit.list(top, 8)
UiKit.scaled(top)

local panel = UiKit.panel(top, "Status")
panel.LayoutOrder = 1
panel.Size = UDim2.new(1, 0, 0, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
UiKit.padding(panel, 10, 6)
local stack = UiKit.list(panel, 4, nil, Enum.HorizontalAlignment.Left)

local alerts = Instance.new("Frame")
alerts.Name = "Alerts"
alerts.LayoutOrder = 2
alerts.Size = UDim2.new(1, 0, 0, 0)
alerts.AutomaticSize = Enum.AutomaticSize.Y
alerts.BackgroundTransparency = 1
alerts.Parent = top
UiKit.list(alerts, 6)

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundTransparency = 1
header.Parent = panel

local function label(parent, name, order, size, color)
    local item = UiKit.label(parent, "", size, color, UiKit.BodyFont)
    item.Name = name
    item.LayoutOrder = order
    item.TextXAlignment = Enum.TextXAlignment.Left
    return item
end

local timer = label(header, "Timer", 0, 22, colors.gold)
timer.FontFace = UiKit.Font
timer.Size = UDim2.new(1, -140, 1, 0)
timer.AutomaticSize = Enum.AutomaticSize.None
timer.TextScaled = true
local timerLimit = Instance.new("UITextSizeConstraint")
timerLimit.MaxTextSize = 24
timerLimit.Parent = timer
UiKit.textStroke(timer)
local stats = label(panel, "Stats", 1, 14, colors.white)
local objective = label(panel, "Objective", 2, 15, colors.mint)
objective.FontFace = UiKit.Font
UiKit.textStroke(objective)
local notice = label(panel, "Notice", 3, 14, colors.white)
notice.BackgroundColor3 = palette.inkSoft
notice.BackgroundTransparency = 0.1
UiKit.corner(notice, 8)
UiKit.padding(notice, 8, 4)

-- Wallet: coins, income, speed and rebirths, top-left under the Roblox buttons.
local wallet = Instance.new("Frame")
wallet.Name = "Wallet"
wallet.Position = UDim2.fromOffset(8, 6)
wallet.AutomaticSize = Enum.AutomaticSize.XY
wallet.BackgroundTransparency = 1
wallet.Parent = gui
UiKit.list(wallet, 6, nil, Enum.HorizontalAlignment.Left)
UiKit.scaled(wallet)
local coinPill = UiKit.pill(wallet, "Coins", palette.goldDeep)
coinPill.LayoutOrder = 1
coinPill.TextSize = 20
local incomePill = UiKit.pill(wallet, "Income", Color3.fromRGB(60, 160, 110))
incomePill.LayoutOrder = 2
local speedPill = UiKit.pill(wallet, "Speed", palette.sky)
speedPill.LayoutOrder = 3
local rebirthPill = UiKit.pill(wallet, "Rebirths", palette.pink)
rebirthPill.LayoutOrder = 4

-- Left-edge column for action buttons, clear of the thumbstick and jump button.
local side = Instance.new("Frame")
side.Name = "Side"
side.AnchorPoint = Vector2.new(0, 0.5)
side.Position = UDim2.new(0, 8, 0.5, 0)
side.AutomaticSize = Enum.AutomaticSize.XY
side.BackgroundTransparency = 1
side.Parent = gui
UiKit.list(side, 8, nil, Enum.HorizontalAlignment.Left)
UiKit.scaled(side)

local function updateWallet()
    local weekly = player:GetAttribute("WeeklyStartsAt") ~= nil
    wallet.Visible = not weekly
    UiKit.countTo(coinPill, player:GetAttribute("Coins") or 0, function(value)
        return "🪙 " .. tostring(value)
    end)
    incomePill.Text = "💰 " .. text("База +%d/мин", player:GetAttribute("BaseIncome") or 0)
    speedPill.Text = "⚡ " .. text("Скорость %d/%d", player:GetAttribute("SpeedTier") or 1, #Rules.Speeds)
    local rebirths = player:GetAttribute("Rebirths") or 0
    rebirthPill.Visible = rebirths > 0
    rebirthPill.Text = "🌸 " .. text("Перерождений: %d", rebirths)
end
for _, name in ipairs({ "Coins", "BaseIncome", "SpeedTier", "Rebirths", "WeeklyStartsAt" }) do
    player:GetAttributeChangedSignal(name):Connect(updateWallet)
end
updateWallet()

gui.Parent = player:WaitForChild("PlayerGui")
local updateFeedback = RunFeedback.connect(gui, shared:WaitForChild("RunFeedback"), Rules, player, locale)
local resultCard = gui:FindFirstChild("RunResult")
if resultCard then
    UiKit.scaled(resultCard)
end

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
waypoint.Name = "RouteWaypoint"
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
    button.FontFace = UiKit.Font
    button.TextSize = 15
    button.AutoButtonColor = true
    button.BackgroundColor3 = background
    button.TextColor3 = foreground
    button.Parent = parent
    UiKit.corner(button, 12)
    UiKit.stroke(button, palette.ink, 2)
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

local returnHints = {
    vineExit = text("По лиане в лагерь"),
    vineBypass = text("Лиана закрылась · по обычному мосту"),
    windExit = text("По тропе к Луговому острову"),
}

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
    -- Coins, speed and income are in the wallet; this line is only for the weekly run.
    stats.Text = ""
    local prizeStatus = if Rules.canUseVault(tier, Rules.Vaults[3]) then round:GetAttribute("PrizeStatus_storm_" .. locale.language)
        elseif Rules.canUseVault(tier, Rules.Vaults[2]) then round:GetAttribute("PrizeStatus_amber_" .. locale.language)
        else round:GetAttribute("PrizeStatus_meadow_" .. locale.language) or text("Луговое яйцо доступно каждому")
    objective.Text = if delivered then text("Яйцо спасено") else prizeStatus or ""
    local target
    if carrying then
        local route = player:GetAttribute("EggReturnTarget")
            or (if abilityId == "anchor" then "windEntrance" else abilityId)
        local marker = abilityTargets[route]
        target = marker and marker.Value or hatchTarget.Value
        objective.Text = returnHints[route] or (if ability and marker then text(ability.hint) else text("К инкубатору"))
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
    waypoint.Adornee = if weeklyPoint or (carrying and not weeklyStart) then target else nil
    if waypoint.Adornee then
        local height = if weeklyPoint then 2 else waypoint.Adornee.Size.Y / 2 + 3.25
        waypoint.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
    end
    guide.Adornee = target
    stats.Visible = stats.Text ~= ""
    if objective.Text ~= "" and not string.find(objective.Text, "🎯", 1, true) then
        objective.Text = "🎯 " .. objective.Text
    end
    objective.Visible = objective.Text ~= ""
    updateGuide()
    updateNotice()
end

for _, name in ipairs({ "BaseIncome", "OnboardingStep", "Coins", "SpeedTier", "CarryingEgg", "EggAbility", "EggReturnTarget", "Delivered", "WeeklyStep", "WeeklyStartsAt" }) do
    player:GetAttributeChangedSignal(name):Connect(update)
end
for _, name in ipairs({ "Notice", "NoticeUntil", "WindEffect", "WeeklySplitText" }) do
    player:GetAttributeChangedSignal(name):Connect(updateNotice)
end
for _, definition in ipairs(Rules.Prizes) do
    round:GetAttributeChangedSignal("PrizeStatus_" .. definition.id .. "_" .. locale.language):Connect(update)
end
for _, targets in ipairs({ { gateTarget, eggTarget, hatchTarget, trainingTarget }, abilityTargets }) do
    for _, target in pairs(targets) do
        target:GetPropertyChangedSignal("Value"):Connect(update)
    end
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
        timer.Text = (if closing then "⏰ " elseif open then "🏃 " else "⏳ ") .. text("%s  ·  %02d сек", text(phase), left)
        timer.TextColor3 = if closing then palette.danger else colors.gold
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
