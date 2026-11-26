-- Glider control. Jump again while falling to open or close the glider.
-- Launch pads throw you up and open the glider automatically.
-- Works with keyboard, gamepad and the mobile jump button through JumpRequest.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Eggstride")
local Glide = require(Shared:WaitForChild("Glide"))
local locale = require(script.Parent.InterfaceLanguage)

local player = Players.LocalPlayer
local remote = Shared:WaitForChild("Glide")

local padsById = {}
for _, pad in ipairs(Glide.Pads) do
    padsById[pad.id] = pad
end

local humanoid, root
local gliding = false
local launchedAt = 0
local launchDirection
local guidedPad
local lastPadAt = 0
local hintShown = false

local gui = Instance.new("ScreenGui")
gui.Name = "EggstrideGlider"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -120)
hint.Size = UDim2.fromOffset(300, 30)
hint.BackgroundColor3 = Color3.fromRGB(40, 37, 73)
hint.BackgroundTransparency = 0.2
hint.TextColor3 = Color3.fromRGB(255, 223, 155)
hint.Font = Enum.Font.GothamBold
hint.TextScaled = true
hint.Visible = false
hint.Parent = gui
Instance.new("UICorner", hint).CornerRadius = UDim.new(0, 8)

local function showHint(source)
    hint.Text = locale.text(source)
    hint.Visible = true
    task.delay(3, function()
        if hint.Text == locale.text(source) then
            hint.Visible = false
        end
    end)
end

local function allowed()
    return humanoid and root and humanoid.Health > 0 and player:GetAttribute("WeeklyStep") == nil
end

local function setGliding(value)
    if gliding == value then
        return
    end
    gliding = value
    remote:FireServer(value)
    if not value then
        launchDirection = nil
        guidedPad = nil
    end
end

local function airborne()
    local state = humanoid:GetState()
    return state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
end

UserInputService.JumpRequest:Connect(function()
    if not allowed() then
        return
    end
    -- The first jump leaves the ground; a jump in the air toggles the glider.
    if airborne() and os.clock() - launchedAt > 0.25 then
        setGliding(not gliding)
    end
end)

local function launch(padId)
    local pad = padsById[padId]
    if not pad or not allowed() or os.clock() - lastPadAt < Glide.PadCooldown then
        return
    end
    lastPadAt = os.clock()
    launchedAt = os.clock()
    local velocity = Glide.padVelocity(pad)
    launchDirection = Vector3.new(pad.direction, 0, 0)
    guidedPad = pad
    root.CFrame = CFrame.lookAt(root.Position, root.Position + launchDirection)
    root.AssemblyLinearVelocity = Vector3.new(velocity.x, velocity.y, velocity.z)
    humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
    setGliding(true)
    if not hintShown then
        hintShown = true
        showHint("Прыжок в воздухе — сложить или раскрыть планер")
    end
end

local function bindPad(plate)
    plate.Touched:Connect(function(hit)
        if root and hit == root then
            launch(plate:GetAttribute("PadId"))
        end
    end)
end
CollectionService:GetInstanceAddedSignal("EggstrideLaunchPad"):Connect(bindPad)
for _, plate in ipairs(CollectionService:GetTagged("EggstrideLaunchPad")) do
    bindPad(plate)
end

local function onCharacter(character)
    gliding = false
    humanoid = character:WaitForChild("Humanoid")
    root = character:WaitForChild("HumanoidRootPart")
    humanoid.StateChanged:Connect(function(_, state)
        if state == Enum.HumanoidStateType.Landed or state == Enum.HumanoidStateType.Running
            or state == Enum.HumanoidStateType.Swimming or state == Enum.HumanoidStateType.Dead then
            setGliding(false)
        elseif state == Enum.HumanoidStateType.Freefall and not hintShown and not gliding then
            hintShown = true
            showHint("Прыжок в воздухе — раскрыть планер")
        end
    end)
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
    task.spawn(onCharacter, player.Character)
end

RunService.Heartbeat:Connect(function()
    if not gliding then
        return
    end
    if not allowed() then
        setGliding(false)
        return
    end
    -- Pad flights ignore steering and fold above the target island.
    if guidedPad and Glide.passedTarget(guidedPad, root.Position.X) then
        local velocity = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(guidedPad.direction * Glide.LandingDrift, math.min(velocity.Y, 0), 0)
        setGliding(false)
        return
    end
    local direction = if guidedPad then launchDirection else humanoid.MoveDirection
    if direction.Magnitude < 0.1 then
        direction = launchDirection or Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
    end
    if direction.Magnitude < 0.01 then
        return
    end
    direction = direction.Unit
    local speed = Glide.horizontalSpeed(humanoid.WalkSpeed)
    local position = root.Position
    local inUpdraft = false
    for _, updraft in ipairs(Glide.Updrafts) do
        if Glide.inUpdraft(updraft, position) then
            inUpdraft = true
        end
    end
    local sink = Glide.sinkMultiplier(player:GetAttribute("CarryingEgg") == true,
        player:GetAttribute("CarryingStolen") ~= nil, player:GetAttribute("EggStage"))
    local vertical = Glide.verticalSpeed(root.AssemblyLinearVelocity.Y, sink, inUpdraft)
    root.AssemblyLinearVelocity = Vector3.new(direction.X * speed, vertical, direction.Z * speed)
end)
