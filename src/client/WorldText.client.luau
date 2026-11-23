local CollectionService = game:GetService("CollectionService")
local locale = require(script.Parent.InterfaceLanguage)

local tag = "EggstrideWorldText"
local connections = {}

local function bind(instance)
    if connections[instance] then
        return
    end
    local function display()
        local source = instance:GetAttribute("SourceText")
        if not source then
            return
        end
        if instance:IsA("TextLabel") then
            -- Wind signs have two independently translated lines.
            local first, second = string.match(source, "^([^\n]+)\n([^\n]+)$")
            instance.Text = if first then locale.text(first) .. "\n" .. locale.text(second) else locale.text(source)
        elseif instance:IsA("ProximityPrompt") then
            instance.ActionText = locale.text(source)
        end
    end
    connections[instance] = instance:GetAttributeChangedSignal("SourceText"):Connect(display)
    display()
end

CollectionService:GetInstanceAddedSignal(tag):Connect(bind)
CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
    local connection = connections[instance]
    if connection then
        connection:Disconnect()
        connections[instance] = nil
    end
end)
for _, instance in ipairs(CollectionService:GetTagged(tag)) do
    bind(instance)
end
