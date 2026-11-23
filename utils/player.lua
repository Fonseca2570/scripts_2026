local API = require("api")

local Player = {}

function Player.isBusy()
    return API.ReadPlayerAnim() > 0 or API.ReadPlayerMovin2() or API.isProcessing()
end

-- A click takes a tick or two to turn into walking or an animation, so a loop
-- that checks straight away sees an idle player and clicks again. Returns false
-- when the player is still idle after about three seconds.
function Player.waitUntilBusy()
    for _ = 1, 20 do
        API.RandomSleep2(100, 50, 50)
        if Player.isBusy() then
            return true
        end
    end
    return false
end

-- Waits for an action that is already under way to finish. Returns false when
-- the player is still busy after about ten seconds.
function Player.waitUntilIdle()
    for _ = 1, 60 do
        API.RandomSleep2(150, 50, 50)
        if not Player.isBusy() then
            return true
        end
    end
    return false
end

return Player
