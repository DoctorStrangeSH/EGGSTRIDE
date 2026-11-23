local CollectionService = game:GetService("CollectionService")

local CampThemes = {}

function CampThemes.connect(player, rules)
    local themes = {}
    for _, theme in ipairs(rules.CampThemes) do
        themes[theme.id] = theme
    end

    local preview
    local function current()
        return preview or themes[player:GetAttribute("EquippedCampTheme")] or rules.CampPalette
    end

    local function refresh()
        local palette = current()
        for _, role in ipairs({ "first", "last", "glow" }) do
            local color = Color3.fromRGB(table.unpack(palette[role]))
            for _, piece in ipairs(CollectionService:GetTagged("EggstrideCamp_" .. role)) do
                if piece:IsA("BasePart") then
                    piece.Color = color
                end
            end
        end
    end

    for _, role in ipairs({ "first", "last", "glow" }) do
        CollectionService:GetInstanceAddedSignal("EggstrideCamp_" .. role):Connect(function(piece)
            if piece:IsA("BasePart") then
                piece.Color = Color3.fromRGB(table.unpack(current()[role]))
            end
        end)
    end
    player:GetAttributeChangedSignal("EquippedCampTheme"):Connect(function()
        preview = nil
        refresh()
    end)
    refresh()

    local previewNumber = 0
    return function(theme)
        previewNumber += 1
        local sample = previewNumber
        preview = theme
        refresh()
        task.delay(12, function()
            if previewNumber == sample and preview then
                preview = nil
                refresh()
            end
        end)
    end
end

return CampThemes
