local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local WeeklyLeaderboard = {}
WeeklyLeaderboard.__index = WeeklyLeaderboard

local PAGE_SIZE = 10
local LOADING = "Загружаем результаты…"
local EMPTY = "Пока нет результатов"
local UNAVAILABLE = "Таблица временно недоступна"

function WeeklyLeaderboard.new(round, rules, locale)
    local feed = Instance.new("StringValue")
    feed.Name = "WeeklyLeaderboard"
    feed.Value = LOADING
    feed:SetAttribute("EnglishResults", locale.text("en", LOADING))
    feed.Parent = round
    local storeName
    if not RunService:IsStudio() then
        storeName = "EggstrideWeekly_v1"
    elseif workspace:GetAttribute("UseStudioDataStore") == true then
        storeName = "EggstrideStudioWeekly_v1"
    end
    feed:SetAttribute("SessionOnly", storeName == nil)
    return setmetatable({
        feed = feed, rules = rules, locale = locale, storeName = storeName, names = {}, results = {},
        week = nil, refreshing = false, nextRefreshAt = 0,
    }, WeeklyLeaderboard)
end

function WeeklyLeaderboard:storeFor(week)
    return DataStoreService:GetOrderedDataStore(self.storeName, "week_" .. week)
end

function WeeklyLeaderboard:showStatus(status)
    self.feed.Value = status
    self.feed:SetAttribute("EnglishResults", self.locale.text("en", status))
end

function WeeklyLeaderboard:show(results)
    if #results == 0 then
        self:showStatus(EMPTY)
        return
    end

    local function formatRows(language)
        local lines = {}
        for index, result in ipairs(results) do
            local name = result.name or self.locale.text(language, "Игрок %s", result.id)
            local time = self.locale.deliveryTime(language, result.time)
            table.insert(lines, string.format("%d. %s  ·  %s", index, name, time))
        end
        return table.concat(lines, "\n")
    end
    self.feed.Value = formatRows("ru")
    self.feed:SetAttribute("EnglishResults", formatRows("en"))
end

function WeeklyLeaderboard:refresh(week)
    if self.week ~= week then
        self.week = week
        self.results = {}
        self.nextRefreshAt = 0
        self:showStatus(if self.storeName then LOADING else EMPTY)
    end
    if not self.storeName or self.refreshing or os.clock() < self.nextRefreshAt then
        return
    end

    self.refreshing = true
    self.nextRefreshAt = os.clock() + 45
    task.defer(function()
        local ok, page = pcall(function()
            return self:storeFor(week):GetSortedAsync(true, PAGE_SIZE, 1, self.rules.Weekly.duration * 1000):GetCurrentPage()
        end)
        local results = {}
        if ok then
            for _, row in ipairs(page) do
                local id = tonumber(row.key)
                local online = id and Players:GetPlayerByUserId(id)
                local name = if online then online.Name else self.names[id]
                if not name and id and id > 0 then
                    local found, username = pcall(Players.GetNameFromUserIdAsync, Players, id)
                    if found then
                        self.names[id] = username
                        name = username
                    end
                end
                table.insert(results, { name = name, id = row.key, time = row.value })
            end
        end
        self.refreshing = false
        if self.week ~= week or self.rules.weekId(os.time()) ~= week then
            return
        end
        if ok then
            self:show(results)
        elseif self.feed.Value == LOADING then
            self:showStatus(UNAVAILABLE)
        end
    end)
end

function WeeklyLeaderboard:submit(userId, name, week, time)
    if not self.storeName then
        if week ~= self.rules.weekId(os.time()) then
            return
        end
        self:refresh(week)
        local prior = self.results[userId]
        if prior and prior.time <= time then
            return
        end
        self.results[userId] = { id = userId, name = name, time = time }
        local results = {}
        for _, result in pairs(self.results) do
            table.insert(results, result)
        end
        table.sort(results, function(a, b)
            return a.time < b.time or (a.time == b.time and a.id < b.id)
        end)
        while #results > PAGE_SIZE do
            table.remove(results)
        end
        self:show(results)
        return
    end

    for attempt = 1, 3 do
        local ok = pcall(function()
            self:storeFor(week):UpdateAsync(tostring(userId), function(previous)
                if type(previous) == "number" and previous <= time then
                    return nil
                end
                return time
            end)
        end)
        if ok then
            return
        end
        if attempt < 3 then
            task.wait(attempt)
        end
    end
    warn("EGGSTRIDE: weekly leaderboard write unavailable", userId)
end

return WeeklyLeaderboard
