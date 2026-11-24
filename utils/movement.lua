local API = require("api")
local Slib = require("slib")

local Movement = {}

-- Underground maps (dungeons, the Dwarven mines) sit 6400 tiles north of the
-- surface, so a tile's y tells which side of a ladder it is on.
local UndergroundY = 6400
local ClimbDown = "Climb-down"
local ClimbUp = "Climb-up"
local EntranceRange = 5
local StandOff = 3

function Movement.isNear(tile, radius)
    return Slib:IsPlayerInArea(tile.x, tile.y, tile.z, radius)
end

local function towards(from, to)
    if to > from then
        return 1
    end
    if to < from then
        return -1
    end
    return 0
end

-- Spot tiles are usually the rock, tree, booth or ladder itself, which the
-- player can't stand on, and Slib:MoveTo keeps clicking until the player is on
-- the exact tile. So stop StandOff tiles short of it on the player's side,
-- far enough to clear objects bigger than one tile.
function Movement.moveTo(tile)
    local player = API.PlayerCoord()
    Slib:MoveTo(
        tile.x + StandOff * towards(tile.x, player.x),
        tile.y + StandOff * towards(tile.y, player.y),
        tile.z
    )
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
