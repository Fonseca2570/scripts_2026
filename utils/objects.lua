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

return Objects
