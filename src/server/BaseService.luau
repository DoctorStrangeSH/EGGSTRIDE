-- Server side of player bases: plot assignment, passive income, stealing,
-- base lock, slot upgrades and Developer Products (shield, double income).
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Eggstride")
local Bases = require(Shared.Bases)
local BaseWorld = require(script.Parent.BaseWorld)

local BaseService = {}

local function now()
    return workspace:GetServerTimeNow()
end

local function productIds()
    local ids, byId = {}, {}
    for _, key in ipairs(Bases.ProductOrder) do
        local value = workspace:GetAttribute("ProductId_" .. key)
        if type(value) == "number" and value > 0 and value % 1 == 0 and value <= 9e15 and not byId[value] then
            ids[key] = value
            byId[value] = key
        end
    end
    return ids, byId
end

-- deps: entries, catalog, publish, characterParts, applySpeed, save, isClosing, expired, inStudio
function BaseService.new(parent, deps)
    local self = {}
    local plots = BaseWorld.build(parent)
    local owners = {} -- plot index -> player
    local entries = deps.entries
    local catalog = deps.catalog
    local publish = deps.publish
    local translate = deps.translate
    local ids, keysById = productIds()

    local remote = Instance.new("RemoteEvent")
    remote.Name = "BaseAction"
    remote.Parent = Shared
    for key, id in pairs(ids) do
        Shared:SetAttribute("ProductId_" .. key, id)
    end
    -- Studio without product IDs: the client shows test purchase buttons.
    local studioProducts = deps.inStudio and next(ids) == nil
    Shared:SetAttribute("StudioProducts", studioProducts)

    local function ready(entry)
        return entry and not deps.isClosing() and not deps.expired(entry.session)
    end

    local function plotOf(entry)
        return entry.plot and plots[entry.plot]
    end

    local function boosted(entry)
        return (entry.incomeBoostUntil or 0) > os.time()
    end

    local function refreshPlot(player, entry)
        local plot = plotOf(entry)
        if not plot then
            return
        end
        local model = plot.model
        local perMinute = Bases.totalIncome(entry.base, catalog, boosted(entry))
        model:SetAttribute("OwnerUserId", player.UserId)
        model:SetAttribute("OwnerName", player.DisplayName)
        model:SetAttribute("Income", perMinute)
        model:SetAttribute("Slots", entry.baseSlots)
        model:SetAttribute("Pets", #entry.base)
        model:SetAttribute("NextSlotCost", Bases.nextSlotCost(entry.baseSlots) or 0)
        model:SetAttribute("LockedUntil", entry.lockedUntil or 0)
        -- Paid timers are stored as os.time(); convert to server clock for the client.
        local shieldLeft = math.max(0, (entry.shieldUntil or 0) - os.time())
        model:SetAttribute("ShieldUntil", if shieldLeft > 0 then now() + shieldLeft else 0)
        local boostLeft = math.max(0, (entry.incomeBoostUntil or 0) - os.time())
        model:SetAttribute("BoostUntil", if boostLeft > 0 then now() + boostLeft else 0)
        player:SetAttribute("BaseIncome", perMinute)
        player:SetAttribute("BasePlot", plot.index)
        for slot, view in ipairs(plot.slots) do
            local id = entry.base[slot]
            local pet = id and catalog[id]
            local open = slot <= entry.baseSlots
            view.pedestal.Transparency = if open then 0 else 0.7
            view.prompt.Enabled = pet ~= nil
            -- Name and price first: the client redraws the prompt when PetId changes.
            view.pedestal:SetAttribute("PetName", if pet then pet.name else "")
            view.pedestal:SetAttribute("SellPrice", if pet then Bases.sellPrice(pet) else 0)
            view.pedestal:SetAttribute("PetId", id or "")
            if view.shownId ~= id then
                view.shownId = id
                BaseWorld.showPet(view, pet, pet and pet.name or "")
            end
        end
    end

    local function clearPlot(plot)
        local model = plot.model
        for _, name in ipairs({ "OwnerName", "Income", "Slots", "Pets", "NextSlotCost", "LockedUntil", "ShieldUntil", "BoostUntil", "Pending" }) do
            model:SetAttribute(name, nil)
        end
        model:SetAttribute("OwnerUserId", 0)
        for _, view in ipairs(plot.slots) do
            view.prompt.Enabled = false
            view.shownId = nil
            view.pedestal.Transparency = 0
            view.pedestal:SetAttribute("PetName", "")
            view.pedestal:SetAttribute("SellPrice", 0)
            view.pedestal:SetAttribute("PetId", "")
            BaseWorld.showPet(view, nil)
        end
    end

    local function lockState(entry, t)
        local shield = (entry.shieldUntil or 0) - os.time()
        return {
            base = entry.base,
            slots = entry.baseSlots,
            lockedUntil = entry.lockedUntil,
            shieldUntil = if shield > 0 then t + shield else 0,
            beingStolen = entry.beingStolen,
            carryingEgg = entry.egg ~= nil,
            stolen = entry.stolen,
        }
    end

    local function clearCarry(thief, entry)
        local carry = entry.stolen
        if not carry then
            return
        end
        entry.stolen = nil
        local victimEntry = entries[carry.victim]
        if victimEntry and victimEntry.beingStolen then
            victimEntry.beingStolen[thief] = nil
            if carry.victim.Parent then
                carry.victim:SetAttribute("BaseRobbed", nil)
            end
        end
        for _, field in ipairs({ "visual", "highlight", "tag" }) do
            if carry[field] then
                carry[field]:Destroy()
            end
        end
        thief:SetAttribute("CarryingStolen", nil)
        deps.applySpeed(thief, entry)
    end

    function self.dropStolen(player, entry, message)
        if entry.stolen then
            local victim = entry.stolen.victim
            clearCarry(player, entry)
            if message then
                publish(player, entry, message)
            end
            local victimEntry = entries[victim]
            if victimEntry and message then
                publish(victim, victimEntry, "Питомец вернулся на твою базу!")
            end
        end
    end

    function self.join(player, entry, record)
        entry.base = record.base
        entry.baseSlots = record.baseSlots
        entry.shieldUntil = record.shieldUntil
        entry.incomeBoostUntil = record.incomeBoostUntil
        entry.receipts = record.receipts
        entry.pending = 0
        entry.beingStolen = {}
        entry.lockedUntil = now() + Bases.JoinProtectionSeconds
        entry.nextBaseActionAt = 0
        for index, plot in ipairs(plots) do
            if not owners[index] then
                owners[index] = player
                entry.plot = index
                break
            end
        end
        refreshPlot(player, entry)
    end

    function self.leave(player, entry)
        self.dropStolen(player, entry)
        -- Anyone carrying this player's pet loses it: the profile is saved without changes.
        for thief in pairs(entry.beingStolen or {}) do
            local thiefEntry = entries[thief]
            if thiefEntry then
                clearCarry(thief, thiefEntry)
                publish(thief, thiefEntry, "Хозяин ушёл, питомец убежал домой.")
            end
        end
        entry.coins += math.floor(entry.pending or 0)
        entry.pending = 0
        local plot = plotOf(entry)
        if plot and owners[plot.index] == player then
            owners[plot.index] = nil
            clearPlot(plot)
        end
        entry.plot = nil
    end

    -- Called after a hatch. Returns true if the pet went to the base.
    function self.addPet(player, entry, pet)
        local slot = Bases.place(entry.base, entry.baseSlots, pet.id)
        refreshPlot(player, entry)
        return slot ~= nil
    end

    local function collect(player, entry)
        local amount = math.floor(entry.pending)
        if amount <= 0 then
            return
        end
        entry.pending -= amount
        entry.coins += amount
        publish(player, entry, "Собрано с базы: %d монет.", amount)
        local plot = plotOf(entry)
        if plot then
            plot.model:SetAttribute("Pending", math.floor(entry.pending))
        end
    end

    local function nearPlot(root, plot, radius)
        local offset = root.Position - plot.center
        return math.abs(offset.X) <= radius and math.abs(offset.Z) <= radius and offset.Y < 12
    end

    local function lock(player, entry)
        local t = now()
        if Bases.isLocked(entry.lockedUntil, 0, t) then
            return
        end
        entry.lockedUntil = t + Bases.LockSeconds
        refreshPlot(player, entry)
        publish(player, entry, "База закрыта на %d секунд.", Bases.LockSeconds)
    end

    local function buySlot(player, entry)
        local cost = Bases.nextSlotCost(entry.baseSlots)
        if not cost then
            publish(player, entry, "На базе уже максимум слотов.")
            return
        end
        if entry.coins < cost then
            publish(player, entry, "Новый слот стоит %d монет. Не хватает %d.", cost, cost - entry.coins)
            return
        end
        entry.coins -= cost
        entry.baseSlots += 1
        refreshPlot(player, entry)
        publish(player, entry, "Открыт новый слот: %d из %d.", entry.baseSlots, Bases.MaxSlots)
    end

    local function sell(player, entry, slot)
        if next(entry.beingStolen) then
            publish(player, entry, "Сейчас нельзя продать: у тебя крадут питомца!")
            return
        end
        local id = entry.base[slot]
        local pet = id and catalog[id]
        if not pet or not Bases.take(entry.base, slot, id) then
            return
        end
        local price = Bases.sellPrice(pet)
        entry.coins += price
        refreshPlot(player, entry)
        publish(player, entry, "Продан питомец: %s, +%d монет.", translate(player, pet.name), price)
    end

    local function steal(thief, thiefEntry, victim, victimEntry, slot)
        local t = now()
        local ok, reason = Bases.canSteal(lockState(thiefEntry, t), lockState(victimEntry, t), slot, t)
        if not ok then
            if reason == "locked" then
                publish(thief, thiefEntry, "База закрыта. Подожди, пока замок спадёт.")
            elseif reason == "full" then
                publish(thief, thiefEntry, "На твоей базе нет места. Купи слот или продай питомца.")
            elseif reason == "busy" then
                publish(thief, thiefEntry, "Руки заняты: сначала донеси груз.")
            end
            return
        end
        local _, root = deps.characterParts(thief)
        if not root or not thiefEntry.plot then
            return
        end
        local id = victimEntry.base[slot]
        local pet = catalog[id]
        local visual = Instance.new("Part")
        visual.Name = "StolenPet"
        visual.Shape = Enum.PartType.Ball
        visual.Size = Vector3.new(1.8, 1.8, 1.8)
        visual.Color = Color3.fromRGB(table.unpack(pet.color))
        visual.Material = Enum.Material.Neon
        visual.CanCollide = false
        visual.Massless = true
        visual.CFrame = root.CFrame * CFrame.new(0, 3.2, 0)
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = root
        weld.Part1 = visual
        weld.Parent = visual
        visual.Parent = thief.Character

        -- Everyone sees the thief: red outline and a bounty tag.
        local highlight = Instance.new("Highlight")
        highlight.Name = "EggstrideThief"
        highlight.FillColor = Color3.fromRGB(230, 60, 80)
        highlight.OutlineColor = Color3.fromRGB(255, 220, 220)
        highlight.FillTransparency = 0.6
        highlight.Parent = thief.Character
        local tag = Instance.new("BillboardGui")
        tag.Name = "EggstrideBounty"
        tag.Size = UDim2.fromOffset(170, 34)
        tag.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
        tag.AlwaysOnTop = true
        tag.MaxDistance = 150
        tag.LightInfluence = 0
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundColor3 = Color3.fromRGB(200, 50, 70)
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Font = Enum.Font.GothamBold
        label.TextScaled = true
        label.AutoLocalize = false
        label:SetAttribute("Bounty", Bases.bounty(pet))
        CollectionService:AddTag(label, "EggstrideBountySign")
        label.Parent = tag
        Instance.new("UICorner", label).CornerRadius = UDim.new(0, 6)
        tag.Parent = root
        thiefEntry.stolen = { victim = victim, slot = slot, petId = id, visual = visual, highlight = highlight, tag = tag,
            catchableAt = os.clock() + Bases.CatchGraceSeconds }
        victimEntry.beingStolen[thief] = slot
        thief:SetAttribute("CarryingStolen", pet.name)
        victim:SetAttribute("BaseRobbed", thief.DisplayName)
        deps.applySpeed(thief, thiefEntry)
        publish(thief, thiefEntry, "Украл: %s! Беги на свою базу.", translate(thief, pet.name))
        publish(victim, victimEntry, "%s крадёт твоего питомца! Догони вора.", thief.DisplayName)
    end

    local function deliver(thief, thiefEntry)
        local carry = thiefEntry.stolen
        local victimEntry = entries[carry.victim]
        local slot = victimEntry and victimEntry.beingStolen[thief]
        if not victimEntry or not slot or not Bases.take(victimEntry.base, slot, carry.petId) then
            clearCarry(thief, thiefEntry)
            return
        end
        -- Other thieves of the same base keep pointing at the right slot.
        for other, otherSlot in pairs(victimEntry.beingStolen) do
            if other ~= thief and otherSlot > slot then
                victimEntry.beingStolen[other] = otherSlot - 1
                local otherEntry = entries[other]
                if otherEntry and otherEntry.stolen then
                    otherEntry.stolen.slot = otherSlot - 1
                end
            end
        end
        local pet = catalog[carry.petId]
        clearCarry(thief, thiefEntry)
        Bases.place(thiefEntry.base, thiefEntry.baseSlots, carry.petId)
        if not thiefEntry.ownedPets[pet.id] then
            thiefEntry.ownedPets[pet.id] = pet
            thief:SetAttribute("OwnsPet_" .. pet.id, true)
        end
        refreshPlot(thief, thiefEntry)
        refreshPlot(carry.victim, victimEntry)
        publish(thief, thiefEntry, "%s теперь на твоей базе!", translate(thief, pet.name))
        publish(carry.victim, victimEntry, "%s украл питомца: %s.", thief.DisplayName, translate(carry.victim, pet.name))
    end

    local function grant(player, entry, key)
        local product = Bases.Products[key]
        local field = if key == "shield" then "shieldUntil" else "incomeBoostUntil"
        entry[field] = math.max(entry[field] or 0, os.time()) + product.seconds
        refreshPlot(player, entry)
        publish(player, entry, "%s включён.", translate(player, product.name))
    end

    -- Wire up plot prompts.
    for index, plot in ipairs(plots) do
        local function owner()
            return owners[index]
        end
        local function guarded(handler)
            return function(player)
                local entry = entries[player]
                local _, root = deps.characterParts(player)
                if not ready(entry) or not root or entry.weekly then
                    return
                end
                local t = os.clock()
                if t < entry.nextBaseActionAt then
                    return
                end
                entry.nextBaseActionAt = t + 0.25
                handler(player, entry, root)
            end
        end
        plot.lockPrompt.Triggered:Connect(guarded(function(player, entry)
            if owner() == player then
                lock(player, entry)
            end
        end))
        plot.slotPrompt.Triggered:Connect(guarded(function(player, entry)
            if owner() == player then
                buySlot(player, entry)
            end
        end))
        for slot, view in ipairs(plot.slots) do
            view.prompt.Triggered:Connect(guarded(function(player, entry, root)
                local victim = owner()
                local victimEntry = victim and entries[victim]
                if not victimEntry or (root.Position - view.pedestal.Position).Magnitude > 12 then
                    return
                end
                if victim == player then
                    sell(player, entry, slot)
                else
                    steal(player, entry, victim, victimEntry, slot)
                end
            end))
        end
        plot.collector.Touched:Connect(function(hit)
            local player = Players:GetPlayerFromCharacter(hit.Parent)
            local entry = player and entries[player]
            if player and owner() == player and ready(entry) then
                collect(player, entry)
            end
        end)
    end

    remote.OnServerEvent:Connect(function(player, action, key)
        local entry = entries[player]
        if not ready(entry) or typeof(action) ~= "string" or typeof(key) ~= "string" or not Bases.Products[key] then
            return
        end
        local t = os.clock()
        if t < entry.nextBaseActionAt then
            return
        end
        entry.nextBaseActionAt = t + 0.5
        if action == "Buy" then
            if ids[key] then
                MarketplaceService:PromptProductPurchase(player, ids[key])
            elseif studioProducts then
                grant(player, entry, key)
            end
        end
    end)

    if next(ids) then
        MarketplaceService.ProcessReceipt = function(receipt)
            local key = keysById[receipt.ProductId]
            local player = Players:GetPlayerByUserId(receipt.PlayerId)
            local entry = player and entries[player]
            if not key or not ready(entry) then
                return Enum.ProductPurchaseDecision.NotProcessedYet
            end
            local Profile = deps.Profile
            if Profile.rememberReceipt(entry, receipt.PurchaseId) then
                grant(player, entry, key)
            end
            -- Grant only counts once the profile with the receipt is stored.
            local ok = deps.save(entry)
            if not ok then
                return Enum.ProductPurchaseDecision.NotProcessedYet
            end
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
    end

    -- The owner has priority; any other free player can catch the thief for the bounty.
    local function findCatcher(thief, thiefRoot)
        local carry = entries[thief].stolen
        local best
        for other, otherEntry in pairs(entries) do
            if other ~= thief and not otherEntry.stolen and not otherEntry.weekly then
                local humanoid, root = deps.characterParts(other)
                if humanoid and humanoid.Health > 0 and root
                    and (root.Position - thiefRoot.Position).Magnitude <= Bases.CatchRadius then
                    if other == carry.victim then
                        return other
                    end
                    best = best or other
                end
            end
        end
        return best
    end

    -- Income, catching thieves and deliveries.
    local last = os.clock()
    RunService.Heartbeat:Connect(function()
        local clock = os.clock()
        local dt = clock - last
        if dt < 0.2 then
            return
        end
        last = clock
        for player, entry in pairs(entries) do
            if entry.base and entry.plot then
                local perMinute = Bases.totalIncome(entry.base, catalog, boosted(entry))
                local before = math.floor(entry.pending)
                entry.pending = Bases.accrue(entry.pending, perMinute, dt)
                local plot = plotOf(entry)
                if math.floor(entry.pending) ~= before then
                    plot.model:SetAttribute("Pending", math.floor(entry.pending))
                end
                if (entry.incomeBoostUntil or 0) > 0 and entry.incomeBoostUntil <= os.time() and plot.model:GetAttribute("BoostUntil") ~= 0 then
                    refreshPlot(player, entry)
                end
                local carry = entry.stolen
                if carry then
                    local humanoid, root = deps.characterParts(player)
                    local victimEntry = entries[carry.victim]
                    if not victimEntry or not humanoid or humanoid.Health <= 0 or not root then
                        clearCarry(player, entry)
                    else
                        local catcher = if os.clock() >= carry.catchableAt then findCatcher(player, root) else nil
                        if catcher == carry.victim then
                            self.dropStolen(player, entry, "Хозяин догнал тебя и забрал питомца!")
                        elseif catcher then
                            local pet = catalog[carry.petId]
                            local reward = Bases.bounty(pet)
                            local catcherEntry = entries[catcher]
                            self.dropStolen(player, entry, "Тебя поймали! Питомец вернулся хозяину.")
                            -- Cooldown stops two friends from farming bounties off each other.
                            if os.clock() >= (catcherEntry.nextBountyAt or 0) then
                                catcherEntry.nextBountyAt = os.clock() + Bases.BountyCooldownSeconds
                                catcherEntry.coins += reward
                                publish(catcher, catcherEntry, "Вор пойман! Награда: %d монет.", reward)
                            else
                                publish(catcher, catcherEntry, "Вор пойман! Награду можно получать раз в минуту.")
                            end
                            publish(carry.victim, victimEntry, "%s поймал вора и вернул твоего питомца!", catcher.DisplayName)
                        elseif nearPlot(root, plot, Bases.DeliverRadius) then
                            deliver(player, entry)
                        end
                    end
                end
            end
        end
    end)

    return self
end

return BaseService
