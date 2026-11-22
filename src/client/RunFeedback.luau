local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local RunFeedback = {}

local function sound(name, file, speed, volume)
    local player = Instance.new("Sound")
    player.Name = "Eggstride" .. name
    player.SoundId = "rbxasset://sounds/" .. file
    player.PlaybackSpeed = speed
    player.Volume = volume
    player.Parent = SoundService
    return player
end

local function addLabel(parent, textSize, y, height)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = textSize
    label.TextWrapped = true
    label.Position = UDim2.fromOffset(12, y)
    label.Size = UDim2.new(1, -24, 0, height)
    label.Parent = parent
    return label
end

function RunFeedback.connect(gui, event, rules)
    local tickSound = sound("Countdown", "volume_slider.ogg", 1.15, 0.30)
    local startSound = sound("GateOpen", "volume_slider.ogg", 1.65, 0.40)
    local hatchSound = sound("Hatch", "action_get_up.mp3", 1.10, 0.50)
    local lossSound = sound("EggLost", "action_jump_land.mp3", 0.75, 0.45)

    local card = Instance.new("Frame")
    card.Name = "RunResult"
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.72)
    card.Size = UDim2.new(0.88, 0, 0, 76)
    card.BackgroundColor3 = Color3.fromRGB(37, 34, 65)
    card.Visible = false
    card.Parent = gui
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)
    Instance.new("UISizeConstraint", card).MaxSize = Vector2.new(380, 76)

    local outline = Instance.new("UIStroke", card)
    outline.Thickness = 2
    local scale = Instance.new("UIScale", card)
    local title = addLabel(card, 18, 6, 30)
    local detail = addLabel(card, 13, 35, 34)
    detail.TextColor3 = Color3.fromRGB(255, 251, 231)

    local lastResult = 0
    local animation
    local function show(heading, description, accent)
        lastResult += 1
        local thisResult = lastResult
        if animation then
            animation:Cancel()
        end
        title.Text = heading
        title.TextColor3 = accent
        detail.Text = description
        outline.Color = accent
        scale.Scale = 0.94
        card.Visible = true
        animation = TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Scale = 1 })
        animation:Play()
        task.delay(2.8, function()
            if lastResult == thisResult then
                card.Visible = false
            end
        end)
    end

    event.OnClientEvent:Connect(function(kind, petName, rarity, coins, isNew, rewardName, personalBest)
        if kind == "Hatch" then
            local accent = if rarity == "Редкий" then Color3.fromRGB(255, 209, 117) else Color3.fromRGB(163, 255, 201)
            local collection = if rewardName then "\nНаграда · " .. rewardName
                elseif personalBest then "\nЛичный рекорд · " .. rules.deliveryTimeText(personalBest)
                else ""
            show(if isNew then petName .. " · новый вид" else petName, string.format("%s питомец · +%d монет%s", rarity, coins, collection), accent)
            hatchSound.PlaybackSpeed = if rarity == "Редкий" then 1.28 else 1.10
            hatchSound:Play()
        elseif kind == "Timeout" or kind == "Fall" then
            local description = if kind == "Timeout" then "Ворота закрылись. Попробуй ещё раз." else "Ты потерял яйцо при падении. Попробуй снова из лагеря."
            show("Яйцо потеряно", description, Color3.fromRGB(255, 147, 137))
            lossSound:Play()
        end
    end)

    local previousOpen
    local previousSecond
    return function(open, seconds, carrying, muted)
        if not muted and open and previousOpen == false then
            startSound:Play()
        elseif not muted and open and carrying and seconds <= 3 and seconds ~= previousSecond then
            tickSound:Play()
        end
        previousOpen = open
        previousSecond = seconds
    end
end

return RunFeedback
