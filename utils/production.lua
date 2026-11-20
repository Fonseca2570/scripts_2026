local API = require("api")

local Production = {}

-- The Make-X window opens when crafting, cooking or fletching more than one
-- item. It remembers the last product picked, and Space starts making it.
function Production.isMakeXOpen()
    return #API.ScanForInterfaceTest2Get2(true, { 1371, 21, -1, 15 }) > 0
end

function Production.confirm()
    API.KeyboardPress2(0x20, 60, 100)
end

return Production
