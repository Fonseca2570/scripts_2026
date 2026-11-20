-- Unit tests for utils/. Run from the repo root with: lua tests/utils_test.lua
-- The game globals (API, Slib, Inventory, Interact, Item) are replaced by fakes.

local calls = {}

local function record(...)
    calls[#calls + 1] = { ... }
end

local objects = {}
local bank = {}
local boxAccepts = true
local inventory = {}

local fakeApi = {
    RandomSleep2 = function() end,
    Read_LoopyLoop = function() return true end,
    Write_LoopyLoop = function(value) record("Write_LoopyLoop", value) end,
    Dist_FLP = function(tile) return tile end,
    ReadAllObjectsArray = function() return objects end,
    Container_Get_all = function() return bank end,
    PlayerCoord = function() return { x = 1, y = 2, z = 3 } end,
    OFF_ACT_GeneralInterface_route = 0,
    DoAction_Inventory1 = function(id)
        record("DoAction_Inventory1", id)
        if boxAccepts then
            for i = #inventory, 1, -1 do
                if inventory[i].name == "Coal" then
                    table.remove(inventory, i)
                end
            end
        end
    end,
}

local fakeSlib = {
    IsPlayerInArea = function(_, x, y, z, radius)
        record("IsPlayerInArea", x, y, z, radius)
        return true
    end,
    MoveTo = function(_, x, y, z) record("MoveTo", x, y, z) end,
}

package.preload["api"] = function() return fakeApi end
package.preload["slib"] = function() return fakeSlib end

Inventory = {
    GetItems = function() return inventory end,
    Drop = function(_, id)
        for i, item in ipairs(inventory) do
            if item.id == id then
                table.remove(inventory, i)
                return
            end
        end
    end,
}

local itemNames = { [317] = "Raw shrimps", [315] = "Shrimps", [995] = "Coins" }
Item = {
    Get = function(_, id) return { name = itemNames[id] } end,
}

Interact = {
    NPC = function(_, name, action) record("NPC", name, action) end,
    Object = function(_, name, action) record("Object", name, action) end,
}

local Banking = require("utils.banking")
local Gui = require("utils.gui")
local Items = require("utils.items")
local Movement = require("utils.movement")
local Objects = require("utils.objects")

local failures, total = 0, 0

local function check(name, got, expected)
    total = total + 1
    if got ~= expected then
        failures = failures + 1
        print(("FAIL %s: got %s, expected %s"):format(name, tostring(got), tostring(expected)))
    end
end

local function reset()
    calls = {}
    inventory = {}
    objects = {}
    bank = {}
end

local function isRaw(item)
    return Items.lowerName(item):find("^raw ") ~= nil
end

-- Movement

for _, tt in ipairs({
    { name = "copyTile copies every axis", tile = { x = 10, y = 20, z = 1 } },
    { name = "copyTile copies zero z", tile = { x = 3093, y = 3244, z = 0 } },
}) do
    local copy = Movement.copyTile(tt.tile)
    check(tt.name .. " (new table)", copy ~= tt.tile, true)
    check(tt.name .. " (x)", copy.x, tt.tile.x)
    check(tt.name .. " (y)", copy.y, tt.tile.y)
    check(tt.name .. " (z)", copy.z, tt.tile.z)
end

reset()
Movement.isNear({ x = 1, y = 2, z = 0 }, 20)
check("isNear passes tile and radius", table.concat(calls[1], ","), "IsPlayerInArea,1,2,0,20")

reset()
Movement.moveTo({ x = 4, y = 5, z = 1 })
check("moveTo passes tile", table.concat(calls[1], ","), "MoveTo,4,5,1")

-- Items

for _, tt in ipairs({
    { name = "lowerName lowercases", item = { name = "Raw Shrimps" }, expected = "raw shrimps" },
    { name = "lowerName handles nil name", item = {}, expected = "" },
}) do
    check(tt.name, Items.lowerName(tt.item), tt.expected)
end

for _, tt in ipairs({
    {
        name = "find returns first match and count",
        items = { { id = 1, name = "Feather" }, { id = 2, name = "Raw trout" }, { id = 3, name = "Raw salmon" } },
        expectedId = 2,
        expectedCount = 2,
    },
    {
        name = "find with no match",
        items = { { id = 1, name = "Feather" } },
        expectedId = nil,
        expectedCount = 0,
    },
}) do
    reset()
    inventory = tt.items
    local first, count = Items.find(isRaw)
    check(tt.name .. " (id)", first and first.id, tt.expectedId)
    check(tt.name .. " (count)", count, tt.expectedCount)
end

for _, tt in ipairs({
    {
        name = "dropAll drops every match",
        items = { { id = 1, name = "Feather" }, { id = 2, name = "Raw trout" }, { id = 2, name = "Raw trout" } },
        expected = true,
        expectedLeft = 1,
    },
    {
        name = "dropAll with nothing to drop",
        items = { { id = 1, name = "Feather" } },
        expected = false,
        expectedLeft = 1,
    },
}) do
    reset()
    inventory = tt.items
    check(tt.name .. " (result)", Items.dropAll(isRaw), tt.expected)
    check(tt.name .. " (left)", #inventory, tt.expectedLeft)
end

for _, tt in ipairs({
    { name = "fill moves ore into the box", boxAccepts = true, expected = true, expectedLeft = 1 },
    { name = "fill reports a full box", boxAccepts = false, expected = false, expectedLeft = 3 },
}) do
    reset()
    boxAccepts = tt.boxAccepts
    inventory = { { id = 44779, name = "Bronze ore box" }, { id = 453, name = "Coal" }, { id = 453, name = "Coal" } }
    local isCoal = function(item) return item.name == "Coal" end
    check(tt.name .. " (result)", Items.fill(inventory[1], isCoal), tt.expected)
    check(tt.name .. " (left)", #inventory, tt.expectedLeft)
    check(tt.name .. " (clicked box)", calls[1] and calls[1][2], 44779)
end

-- Banking

for _, tt in ipairs({
    {
        name = "open prefers the bank action",
        objects = {
            { Name = "Bank chest", Action = "Use", Type = 0, Tile_XYZ = 1 },
            { Name = "Banker", Action = "Bank", Type = 1, Tile_XYZ = 5 },
        },
        expected = true,
        expectedCall = "NPC,Banker,Bank",
    },
    {
        name = "open falls back to the nearest bank name",
        objects = {
            { Name = "Bank booth", Action = "Use", Type = 0, Tile_XYZ = 3 },
            { Name = "Bank chest", Action = "Use", Type = 0, Tile_XYZ = 1 },
        },
        expected = true,
        expectedCall = "Object,Bank chest,Bank",
    },
    {
        name = "open skips deposit boxes",
        objects = { { Name = "Bank deposit box", Action = "Deposit", Type = 0, Tile_XYZ = 1 } },
        expected = false,
        expectedCall = nil,
    },
}) do
    reset()
    objects = tt.objects
    check(tt.name .. " (result)", Banking.open("Bank"), tt.expected)
    check(tt.name .. " (call)", calls[1] and table.concat(calls[1], ","), tt.expectedCall)
end

for _, tt in ipairs({
    {
        name = "findItem returns first matching bank item",
        bank = {
            { item_id = 995, item_stack = 100 },
            { item_id = 315, item_stack = 5 },
            { item_id = 317, item_stack = 28 },
        },
        expectedId = 317,
        expectedName = "Raw shrimps",
    },
    {
        name = "findItem skips empty slots and placeholders",
        bank = {
            { item_id = -1, item_stack = 0 },
            { item_id = 317, item_stack = 0 },
        },
        expectedId = nil,
        expectedName = nil,
    },
}) do
    reset()
    bank = tt.bank
    local item = Banking.findItem(isRaw)
    check(tt.name .. " (id)", item and item.id, tt.expectedId)
    check(tt.name .. " (name)", item and item.name, tt.expectedName)
end

-- Objects

for _, tt in ipairs({
    {
        name = "nearest picks the closest match",
        objects = {
            { Name = "Fire", Tile_XYZ = 4 },
            { Name = "Range", Tile_XYZ = 9 },
            { Name = "Fire", Tile_XYZ = 2 },
        },
        expectedDistance = 2,
    },
    {
        name = "nearest with no match",
        objects = { { Name = "Range", Tile_XYZ = 1 } },
        expectedDistance = nil,
    },
}) do
    local nearest = Objects.nearest(tt.objects, function(object) return object.Name == "Fire" end)
    check(tt.name, nearest and nearest.Tile_XYZ, tt.expectedDistance)
end

-- Gui

for _, tt in ipairs({
    { name = "indexOf finds zero-based index", list = { "Cage", "Net", "Lure" }, value = "Lure", expected = 2 },
    { name = "indexOf defaults to zero", list = { "Cage", "Net" }, value = "Bait", expected = 0 },
}) do
    check(tt.name, Gui.indexOf(tt.list, tt.value), tt.expected)
end

print(("%d/%d checks passed"):format(total - failures, total))
os.exit(failures == 0 and 0 or 1)
