-- Surface bank tiles the scripts already walk to. The Fishing Guild bank needs
-- 68 Fishing to enter the guild.
local Banks = {
    List = {
        { Name = "Al Kharid", Tile = { x = 3270, y = 3168, z = 0 } },
        { Name = "Draynor", Tile = { x = 3093, y = 3244, z = 0 } },
        { Name = "Varrock west", Tile = { x = 3187, y = 3440, z = 0 } },
        { Name = "Varrock east", Tile = { x = 3254, y = 3421, z = 0 } },
        { Name = "Edgeville", Tile = { x = 3095, y = 3494, z = 0 } },
        { Name = "Falador west", Tile = { x = 2946, y = 3367, z = 0 } },
        { Name = "Falador east", Tile = { x = 3015, y = 3357, z = 0 } },
        { Name = "Burthorpe", Tile = { x = 2889, y = 3533, z = 0 } },
        { Name = "Catherby", Tile = { x = 2795, y = 3440, z = 0 } },
        { Name = "Seers' Village", Tile = { x = 2725, y = 3492, z = 0 } },
        { Name = "Ardougne south", Tile = { x = 2653, y = 3284, z = 0 } },
        { Name = "Fishing Guild", Tile = { x = 2585, y = 3422, z = 0 } },
        { Name = "Sorcerer's Tower", Tile = { x = 2674, y = 3405, z = 0 } },
        { Name = "Oo'glog", Tile = { x = 2412, y = 2827, z = 0 } },
    },
}

function Banks.distance(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

-- Returns the count banks closest to the tile, nearest first.
function Banks.closest(tile, count)
    local sorted = {}
    for i, bank in ipairs(Banks.List) do
        sorted[i] = bank
    end
    table.sort(sorted, function(a, b)
        return Banks.distance(a.Tile, tile) < Banks.distance(b.Tile, tile)
    end)
    return { table.unpack(sorted, 1, math.min(count, #sorted)) }
end

return Banks
