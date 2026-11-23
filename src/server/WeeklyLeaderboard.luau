local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local WeeklyLeaderboard = {}
WeeklyLeaderboard.__index = WeeklyLeaderboard

local PAGE_SIZE = 10

function WeeklyLeaderboard.new(round, rules, locale)
    local feed = Instance.new("StringValue")
    feed.Name = "WeeklyLeaderboard"
    feed.Value = "Загружаем результаты…"
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

function WeeklyLeaderboard:show(results)
    local lines = {}
    for index, result in ipairs(results) do
        table.insert(lines, string.format("%d. %s  ·  %s", index, result.name, self.locale.deliveryTime("ru", result.time)))
    end
    self.feed.Value = if #lines > 0 then table.concat(lines, "\n") else "Пока нет результатов"
end

function WeeklyLeaderboard:refresh(week)
    if self.week ~= week then
        self.week = week
        self.results = {}
        self.nextRefreshAt = 0
        self.feed.Value = if self.storeName then "Загружаем результаты…" else "Пока нет результатов"
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
                table.insert(results, { name = name or "Игрок " .. row.key, time = row.value })
            end
        end
        self.refreshing = false
        if self.week ~= week or self.rules.weekId(os.time()) ~= week then
            return
        end
        if ok then
            self:show(results)
        elseif self.feed.Value == "Загружаем результаты…" then
            self.feed.Value = "Таблица временно недоступна"
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
