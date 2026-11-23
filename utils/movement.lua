local API = require("api")
local Slib = require("slib")

local Movement = {}

-- Underground maps (dungeons, the Dwarven mines) sit 6400 tiles north of the
-- surface, so a tile's y tells which side of a ladder it is on.
local UndergroundY = 6400
local ClimbDown = "Climb-down"
local ClimbUp = "Climb-up"
local EntranceRange = 5

function Movement.isNear(tile, radius)
    return Slib:IsPlayerInArea(tile.x, tile.y, tile.z, radius)
end

function Movement.moveTo(tile)
    Slib:MoveTo(tile.x, tile.y, tile.z)
end

function Movement.copyTile(tile)
    return { x = tile.x, y = tile.y, z = tile.z }
end

function Movement.isUnderground(tile)
    return tile.y > UndergroundY
end

local function waitForLayer(underground)
    for _ = 1, 30 do
        API.RandomSleep2(200, 50, 50)
        if Movement.isUnderground(API.PlayerCoord()) == underground then
            return true
        end
    end
    return false
end

-- Takes the entrance between the surface and an underground map. Going down,
-- walk to the entrance's surface tile and climb down the object there; going
-- up, climb up the nearest object with the entrance's name.
local function changeLayer(underground, entrance)
    if not underground then
        Interact:Object(entrance.Object, ClimbUp)
        waitForLayer(false)
        return
    end

    if not Movement.isNear(entrance.Tile, EntranceRange) then
        Movement.moveTo(entrance.Tile)
        return
    end

    local tile = entrance.Tile
    Interact:Object(entrance.Object, ClimbDown, FFPOINT:new(tile.x, tile.y, tile.z), EntranceRange)
    waitForLayer(true)
end

-- Walks towards tile and returns true once within radius. A tile on the other
-- side of the surface/underground split is reached through entrance
-- ({ Tile = surface tile, Object = ladder or staircase name }).
function Movement.goTo(tile, radius, entrance)
    local underground = Movement.isUnderground(tile)
    if entrance ~= nil and Movement.isUnderground(API.PlayerCoord()) ~= underground then
        changeLayer(underground, entrance)
        return false
    end

    if Movement.isNear(tile, radius) then
        return true
    end
    Movement.moveTo(tile)
    return false
end

return Movement
