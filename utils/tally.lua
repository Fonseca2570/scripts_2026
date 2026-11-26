local Items = require("utils.items")

-- Counts matching items as they arrive in the inventory, by name. Only
-- increases count, so items leaving for the ore box, the bank or the floor
-- aren't counted again. The first update only notes what is already there.
local Tally = {}

function Tally.new()
    return { Counts = {}, Names = {}, Total = 0, Last = nil }
end

local function inventoryCounts(matches)
    local counts = {}
    for _, item in ipairs(Inventory:GetItems()) do
        if matches(item) then
            counts[item.name] = (counts[item.name] or 0) + 1
        end
    end
    return counts
end

function Tally.update(tally, matches)
    local counts = inventoryCounts(matches)
    if tally.Last ~= nil then
        for name, count in pairs(counts) do
            local gained = count - (tally.Last[name] or 0)
            if gained > 0 then
                if tally.Counts[name] == nil then
                    tally.Names[#tally.Names + 1] = name
                end
                tally.Counts[name] = (tally.Counts[name] or 0) + gained
                tally.Total = tally.Total + gained
            end
        end
    end
    tally.Last = counts
end

-- "50 Coal, 20 Iron ore", in the order they were first gained.
function Tally.text(tally)
    local parts = {}
    for i, name in ipairs(tally.Names) do
        parts[i] = ("%d %s"):format(tally.Counts[name], name)
    end
    return table.concat(parts, ", ")
end

return Tally
