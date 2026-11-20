local Slib = require("slib")

local Movement = {}

function Movement.isNear(tile, radius)
    return Slib:IsPlayerInArea(tile.x, tile.y, tile.z, radius)
end

function Movement.moveTo(tile)
    Slib:MoveTo(tile.x, tile.y, tile.z)
end

function Movement.copyTile(tile)
    return { x = tile.x, y = tile.y, z = tile.z }
end

return Movement
