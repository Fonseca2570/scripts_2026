local API = require("api")

local Objects = {}

function Objects.nearest(objects, matches)
    local nearest, nearestDistance = nil, math.huge
    for _, object in ipairs(objects) do
        if matches(object) then
            local distance = API.Dist_FLP(object.Tile_XYZ)
            if distance < nearestDistance then
                nearest, nearestDistance = object, distance
            end
        end
    end
    return nearest
end

-- Like nearest, but measured from a tile instead of the player, and only
-- objects within maxDistance tiles of it.
function Objects.nearestTo(objects, tile, maxDistance, matches)
    local nearest, nearestDistance = nil, maxDistance
    for _, object in ipairs(objects) do
        if matches(object) then
            local distance = math.sqrt((object.Tile_XYZ.x - tile.x) ^ 2 + (object.Tile_XYZ.y - tile.y) ^ 2)
            if distance <= nearestDistance then
                nearest, nearestDistance = object, distance
            end
        end
    end
    return nearest
end

return Objects
