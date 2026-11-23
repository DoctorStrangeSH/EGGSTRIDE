local CosmeticShop = {}

local fields = { trail = "equippedTrail", hatch = "equippedHatchEffect", camp = "equippedCampTheme" }
local attributes = { trail = "EquippedTrail", hatch = "EquippedHatchEffect", camp = "EquippedCampTheme" }
local passPrefixes = { trail = "TrailPass_", hatch = "HatchPass_", camp = "CampPass_" }

function CosmeticShop.select(entry, item, owned, clear)
    if not clear and not owned then
        return false
    end
    entry[fields[item.slot]] = if clear then nil else item.id
    return true
end

function CosmeticShop.passes(catalog, getAttribute, reservedId)
    local ids, counts = {}, {}
    for _, item in ipairs(catalog) do
        local passId = getAttribute(passPrefixes[item.slot] .. item.id)
        if type(passId) == "number" and passId > 0 and passId <= 9e15 and passId % 1 == 0
            and passId ~= reservedId then
            ids[item.id] = passId
            counts[passId] = (counts[passId] or 0) + 1
        end
    end
    for id, passId in pairs(ids) do
        if counts[passId] > 1 then
            ids[id] = nil
        end
    end
    return ids
end

function CosmeticShop.start(catalog, shared, marketplace, studio, preview, reservedId, findEntry)
    local remote = Instance.new("RemoteEvent")
    remote.Name = "CosmeticShop"

    local ids = CosmeticShop.passes(catalog, function(name)
        return workspace:GetAttribute(name)
    end, reservedId)
    local items, byPass = {}, {}
    for _, item in ipairs(catalog) do
        items[item.id] = item
        local passId = ids[item.id]
        if passId and not studio then
            byPass[passId] = item.id
            remote:SetAttribute("Pass_" .. item.id, passId)
        end
    end

    local function apply(player, entry)
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then
            return
        end
        for _, name in ipairs({ "EggstrideRunTrail", "EggstrideTrailTop", "EggstrideTrailBottom" }) do
            local existing = root:FindFirstChild(name)
            if existing then
                existing:Destroy()
            end
        end
        local selection = entry.equippedTrail
        local wearing = selection and entry.cosmeticStatuses[selection] == "owned"
        local id = entry.trailPreview or (wearing and selection)
        local item = id and items[id]
        if not item then
            return
        end

        local top = Instance.new("Attachment")
        top.Name = "EggstrideTrailTop"
        top.Position = Vector3.new(0, -0.9, 0.8)
        top.Parent = root
        local bottom = Instance.new("Attachment")
        bottom.Name = "EggstrideTrailBottom"
        bottom.Position = Vector3.new(0, -2.2, 0.8)
        bottom.Parent = root
        local trail = Instance.new("Trail")
        trail.Name = "EggstrideRunTrail"
        trail.Attachment0 = top
        trail.Attachment1 = bottom
        trail.Color = ColorSequence.new(Color3.fromRGB(table.unpack(item.first)), Color3.fromRGB(table.unpack(item.last)))
        trail.Transparency = NumberSequence.new(0.17, 1)
        trail.FaceCamera = true
        trail.Lifetime = item.lifetime
        trail.MinLength = 0.48
        trail.LightEmission = 0.7
        trail.Parent = root
    end

    local function publishSelection(player, entry, slot)
        local id = entry[fields[slot]]
        local owned = id and entry.cosmeticStatuses[id] == "owned"
        player:SetAttribute(attributes[slot], if owned then id else "")
        if slot == "trail" then
            apply(player, entry)
        end
    end

    local function setStatus(player, entry, id, status)
        entry.cosmeticStatuses[id] = status
        player:SetAttribute("CosmeticStatus_" .. id, status)
        local slot = items[id].slot
        if entry[fields[slot]] == id then
            publishSelection(player, entry, slot)
        end
    end

    local function check(player, entry, id)
        if findEntry(player) ~= entry then
            return
        end
        setStatus(player, entry, id, "checking")
        local ok, owned = pcall(marketplace.UserOwnsGamePassAsync, marketplace, player.UserId, ids[id])
        if findEntry(player) == entry and entry.cosmeticStatuses[id] == "checking" then
            setStatus(player, entry, id, if not ok then "error" elseif owned then "owned" else "locked")
        end
    end

    local function init(player, entry)
        entry.cosmeticStatuses = {}
        entry.nextCosmeticActionAt = 0
        entry.nextCosmeticPurchaseAt = 0
        for slot in pairs(attributes) do
            publishSelection(player, entry, slot)
        end
        for _, item in ipairs(catalog) do
            if preview then
                setStatus(player, entry, item.id, "preview")
            elseif studio or not ids[item.id] then
                setStatus(player, entry, item.id, "unavailable")
            else
                task.spawn(check, player, entry, item.id)
            end
        end
    end

    remote.OnServerEvent:Connect(function(player, action, id)
        local entry = findEntry(player)
        if not entry or not entry.cosmeticStatuses or type(id) ~= "string" or #id > 32
            or not items[id] or (action ~= "equip" and action ~= "unequip" and action ~= "try" and action ~= "buy") then
            return
        end
        local now = os.clock()
        if action == "buy" then
            if now < entry.nextCosmeticPurchaseAt then
                return
            end
            entry.nextCosmeticPurchaseAt = now + 2
        else
            if now < entry.nextCosmeticActionAt then
                return
            end
            entry.nextCosmeticActionAt = now + 0.25
        end
        local status = entry.cosmeticStatuses[id]
        local item = items[id]
        if action == "equip" or action == "unequip" then
            local clear = action == "unequip"
            if clear and entry[fields[item.slot]] ~= id then
                return
            end
            if CosmeticShop.select(entry, item, status == "owned", clear) then
                if item.slot == "trail" then
                    entry.trailPreview = nil
                end
                publishSelection(player, entry, item.slot)
            end
        elseif action == "try" and item.slot == "trail" and not entry.weekly then
            local token = {}
            entry.trailPreview = id
            entry.trailPreviewToken = token
            apply(player, entry)
            task.delay(12, function()
                if findEntry(player) == entry and entry.trailPreviewToken == token then
                    entry.trailPreview = nil
                    apply(player, entry)
                end
            end)
        elseif action == "buy" and preview and status == "preview" then
            setStatus(player, entry, id, "owned")
        elseif action == "buy" and not studio and ids[id] then
            if status == "error" then
                check(player, entry, id)
            elseif status == "locked" and not entry.cosmeticPrompt then
                entry.cosmeticPrompt = id
                setStatus(player, entry, id, "prompting")
                local ok = pcall(marketplace.PromptGamePassPurchase, marketplace, player, ids[id])
                if not ok and findEntry(player) == entry and entry.cosmeticPrompt == id then
                    entry.cosmeticPrompt = nil
                    setStatus(player, entry, id, "error")
                end
            end
        end
    end)

    if next(byPass) then
        marketplace.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
            local id = byPass[passId]
            local entry = findEntry(player)
            if not id or not entry or not entry.cosmeticStatuses then
                return
            end
            if entry.cosmeticPrompt == id then
                entry.cosmeticPrompt = nil
            end
            if purchased then
                setStatus(player, entry, id, "owned")
            elseif entry.cosmeticStatuses[id] == "prompting" then
                setStatus(player, entry, id, "locked")
            end
        end)
    end

    remote.Parent = shared
    return { init = init, apply = apply }
end

return CosmeticShop
