local Locale = require("../src/shared/Locale")
local Rules = require("../src/shared/Rules")

assert(Locale.language("en-us") == "en")
assert(Locale.language("EN-GB") == "en")
assert(Locale.language("ru-ru") == "ru")
assert(Locale.language("fr-fr") == "ru")
assert(Locale.language(nil) == "ru")
assert(Locale.text("en", "Монеты %d  ·  Скорость %d/%d", 15, 1, 5) == "Coins 15  ·  Speed 1/5")
assert(Locale.text("ru", "Монеты %d  ·  Скорость %d/%d", 15, 1, 5) == "Монеты 15  ·  Скорость 1/5")
assert(Locale.text("en", "Доставил: %s", "Player%2") == "Prize delivered by Player%2")
assert(Locale.text("en", "Русский текст") == "Русский текст")
assert(Locale.text("en", "") == "")

assert(Locale.deliveryTime("ru", 10240) == "10,24 сек.")
assert(Locale.deliveryTime("en", 10240) == "10.24s")
assert(Locale.weeklySplit("ru", 4250, nil) == "От старта · 4,25 сек.")
assert(Locale.weeklySplit("ru", 4000, 4250) == "4,00 сек. · 0,25 сек. быстрее")
assert(Locale.weeklySplit("ru", 4500, 4250) == "4,50 сек. · 0,25 сек. медленнее")
assert(Locale.weeklySplit("ru", 4201, 4200) == "4,20 сек. · Вровень с рекордом")
assert(Locale.weeklySplit("en", 4250, nil) == "Elapsed · 4.25s")
assert(Locale.weeklySplit("en", 4000, 4250) == "4.00s · 0.25s faster")
assert(Locale.weeklySplit("en", 4500, 4250) == "4.50s · 0.25s slower")
assert(Locale.weeklySplit("en", 4201, 4200) == "4.20s · Tied with your best")

local function translated(source)
    local translation = Locale.text("en", source)
    assert(translation ~= "" and translation ~= source, "Missing English translation: " .. source)
end

local function checkPet(pet)
    translated(pet.name)
    translated(pet.rarity)
end

for _, vault in ipairs(Rules.Vaults) do
    translated(vault.name)
    translated(vault.material)
    translated("Яйцо · " .. vault.name)
    for _, pet in ipairs(vault.pets) do
        checkPet(pet)
    end
end
for _, prize in ipairs(Rules.Prizes) do
    translated(prize.name)
    translated(prize.location)
    for _, pet in ipairs(prize.pets) do
        checkPet(pet)
    end
end
for _, group in ipairs(Rules.Offspring) do
    for _, pet in ipairs(group) do
        checkPet(pet)
    end
end
for _, mutation in ipairs(Rules.Mutations) do
    checkPet(mutation.pet)
end
for _, pet in ipairs(Rules.SeasonPets) do
    checkPet(pet)
end
for _, rewards in ipairs({ Rules.Season.rewards, Rules.Season.premiumRewards }) do
    for _, reward in ipairs(rewards) do
        translated(reward.label)
    end
end
for _, ability in pairs(Rules.Abilities) do
    translated(ability.hint)
end
for _, label in ipairs(Rules.Weekly.labels) do
    translated(label)
end

print("Eggstride localization: OK")
