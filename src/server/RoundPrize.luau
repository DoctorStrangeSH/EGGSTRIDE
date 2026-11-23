local RoundPrize = {}

function RoundPrize.new()
    return { owner = nil, delivered = false }
end

function RoundPrize.claim(prize, player)
    if prize.owner or prize.delivered then
        return false
    end
    prize.owner = player
    return true
end

function RoundPrize.release(prize, player)
    if prize.owner ~= player then
        return false
    end
    prize.owner = nil
    return true
end

function RoundPrize.deliver(prize, player)
    if not RoundPrize.release(prize, player) then
        return false
    end
    prize.delivered = true
    return true
end

return RoundPrize
