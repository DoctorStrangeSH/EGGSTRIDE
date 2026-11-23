local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Locale = require(ReplicatedStorage:WaitForChild("Eggstride"):WaitForChild("Locale"))

local studioLanguage = RunService:IsStudio() and workspace:GetAttribute("StudioLanguage")
local language = Locale.language(if type(studioLanguage) == "string" then studioLanguage else Players.LocalPlayer.LocaleId)

return {
    language = language,
    text = function(source, ...)
        return Locale.text(language, source, ...)
    end,
    deliveryTime = function(milliseconds)
        return Locale.deliveryTime(language, milliseconds)
    end,
}
