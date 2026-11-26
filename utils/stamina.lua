local API = require("api")

-- Mining stamina, read from the bar over the player. Clicking the rock again
-- refills it. Maximum stamina grows with Mining level, so low is a share of the
-- highest reading seen, not a fixed number. The share is picked at random for
-- each refill, so the clicks don't always come at the same point.
local StaminaLevel = 15
-- At 0 the bar reads the same as when it isn't shown, so the lowest share is
-- just above it.
local MinShare = 0.05
local MaxShare = 0.5

local function randomShare()
    return MinShare + math.random() * (MaxShare - MinShare)
end

local Stamina = {
    Last = 0,
    Max = 0,
    Share = randomShare(),
}

function Stamina.current()
    return API.LocalPlayer_HoverProgress()
end

-- Stamina starts at Mining level 15. Below that, or when the bar is not shown,
-- it reads 0 or less and must not trigger a click every loop. Each time it
-- reports low, the next refill point is picked.
function Stamina.isLow(miningLevel)
    if miningLevel < StaminaLevel then
        return false
    end
    local stamina = Stamina.current()
    Stamina.Last = stamina
    if stamina <= 0 then
        return false
    end
    Stamina.Max = math.max(Stamina.Max, stamina)
    if stamina > Stamina.Max * Stamina.Share then
        return false
    end
    Stamina.Share = randomShare()
    return true
end

return Stamina
