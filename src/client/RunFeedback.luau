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

local function addLabel(parent, order, textSize)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = textSize
    label.TextWrapped = true
    label.LayoutOrder = order
    label.Size = UDim2.new(1, 0, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.Text = ""
    label.Parent = parent
    return label
end

function RunFeedback.connect(gui, event, rules, player)
    local tickSound = sound("Countdown", "volume_slider.ogg", 1.15, 0.30)
    local startSound = sound("GateOpen", "volume_slider.ogg", 1.65, 0.40)
    local hatchSound = sound("Hatch", "action_get_up.mp3", 1.10, 0.50)
    local lossSound = sound("EggLost", "action_jump_land.mp3", 0.75, 0.45)

    local function play(cue)
        if player:GetAttribute("MuteRunSounds") ~= true then
            cue:Play()
        end
    end

    player:GetAttributeChangedSignal("MuteRunSounds"):Connect(function()
        if player:GetAttribute("MuteRunSounds") then
            for _, cue in ipairs({ tickSound, startSound, hatchSound, lossSound }) do
                cue:Stop()
            end
        end
    end)

    local card = Instance.new("Frame")
    card.Name = "RunResult"
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.72)
    card.Size = UDim2.new(1, -24, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = Color3.fromRGB(37, 34, 65)
    card.Visible = false
    card.Parent = gui
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)
    Instance.new("UISizeConstraint", card).MaxSize = Vector2.new(336, math.huge)
    local padding = Instance.new("UIPadding", card)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    local layout = Instance.new("UIListLayout", card)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)

    local outline = Instance.new("UIStroke", card)
    outline.Thickness = 2
    local scale = Instance.new("UIScale", card)
    local title = addLabel(card, 0, 16)
    local detail = addLabel(card, 1, 13)
    detail.TextColor3 = Color3.fromRGB(255, 251, 231)

    local lastResult = 0
    local animation
    local function stopAnimation()
        if animation then
            animation:Cancel()
            animation = nil
        end
        scale.Scale = 1
    end

    player:GetAttributeChangedSignal("ReduceCardMotion"):Connect(function()
        if player:GetAttribute("ReduceCardMotion") then
            stopAnimation()
        end
    end)

    local function show(heading, description, accent)
        lastResult += 1
        local thisResult = lastResult
        stopAnimation()
        title.Text = heading
        title.TextColor3 = accent
        detail.Text = description
        outline.Color = accent
        card.Visible = true
        if player:GetAttribute("ReduceCardMotion") ~= true then
            scale.Scale = 0.94
            animation = TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Scale = 1 })
            animation:Play()
        end
        task.delay(2.8, function()
            if lastResult == thisResult then
                card.Visible = false
            end
        end)
    end

    event.OnClientEvent:Connect(function(kind, ...)
        if kind == "Hatch" then
            local petName, rarity, coins, isNew, rewardName, personalBest, bonus = ...
            local accent = if rarity == "Редкий" then Color3.fromRGB(255, 209, 117) else Color3.fromRGB(163, 255, 201)
            local collection = if bonus and bonus > 0 then "\nПризовое яйцо · бонус " .. bonus
                elseif rewardName then "\nНаграда · " .. rewardName
                elseif personalBest then "\nЛичный рекорд · " .. rules.deliveryTimeText(personalBest)
                else ""
            show(if isNew then petName .. " · новый вид" else petName, string.format("%s питомец · +%d монет%s", rarity, coins, collection), accent)
            hatchSound.PlaybackSpeed = if rarity == "Редкий" then 1.28 else 1.10
            play(hatchSound)
        elseif kind == "WeeklyFinish" then
            local milliseconds, isBest, result, rewardCoins = ...
            local heading = if isBest then "Личный рекорд недели" else "Забег завершён"
            local description = rules.deliveryTimeText(milliseconds) .. " · " .. result
            if rewardCoins then
                description ..= "\nНаграда недели · +" .. rewardCoins .. " монет"
            end
            show(heading, description, Color3.fromRGB(255, 209, 117))
            play(hatchSound)
        elseif kind == "WeeklyCancelled" then
            show("Попытка отменена", "Ты вернулся в лагерь.", Color3.fromRGB(255, 209, 117))
        elseif kind == "WeeklyStopped" then
            local description = ...
            show("Забег прерван", description, Color3.fromRGB(255, 147, 137))
            play(lossSound)
        elseif kind == "Timeout" or kind == "Fall" then
            local description = if kind == "Timeout" then "Ворота закрылись. Попробуй ещё раз." else "Ты потерял яйцо при падении. Попробуй снова из лагеря."
            show("Яйцо потеряно", description, Color3.fromRGB(255, 147, 137))
            play(lossSound)
        end
    end)

    local previousOpen
    local previousSecond
    return function(open, seconds, carrying, muted)
        if not muted and open and previousOpen == false then
            play(startSound)
        elseif not muted and open and carrying and seconds <= 3 and seconds ~= previousSecond then
            play(tickSound)
        end
        previousOpen = open
        previousSecond = seconds
    end
end

return RunFeedback
