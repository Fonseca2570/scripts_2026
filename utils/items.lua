local API = require("api")

local Items = {}

function Items.lowerName(item)
    return item.name and item.name:lower() or ""
end

function Items.find(matches)
    local first, count = nil, 0
    for _, item in ipairs(Inventory:GetItems()) do
        if matches(item) then
            first = first or item
            count = count + 1
        end
    end
    return first, count
end

-- Drop targets an item id, not a slot, so a drop sent before the game removes
-- the previous item hits that same item again. Wait for each drop to land.
local function dropOne(item, matches, count)
    Inventory:Drop(item.id)
    for _ = 1, 10 do
        API.RandomSleep2(100, 50, 50)
        local _, remaining = Items.find(matches)
        if remaining < count then
            return true
        end
    end
    return false
end

function Items.dropAll(matches)
    local item, count = Items.find(matches)
    if item == nil then
        return false
    end

    while item ~= nil and API.Read_LoopyLoop() do
        if not dropOne(item, matches, count) then
            break
        end
        item, count = Items.find(matches)
    end
    return true
end

-- Fill is the first option on wood and ore boxes. Returns false when no
-- matching item left the inventory, which means the box is full.
function Items.fill(box, matches)
    local _, before = Items.find(matches)
    API.DoAction_Inventory1(box.id, 0, 1, API.OFF_ACT_GeneralInterface_route)
    for _ = 1, 15 do
        API.RandomSleep2(100, 50, 50)
        local _, after = Items.find(matches)
        if after < before then
            return true
        end
    end
    return false
end

return Items
