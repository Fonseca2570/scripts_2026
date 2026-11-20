local API = require("api")
local Objects = require("utils.objects")

local Banking = {}

local ObjectType = 0
local NpcType = 1
local BankContainer = 95

local function isBankName(name)
    local lower = name and name:lower() or ""
    return lower:find("bank", 1, true) ~= nil and lower:find("deposit", 1, true) == nil
end

-- Banks have different names (Bank booth, Bank chest, Banker...) and can be
-- objects or NPCs, so look for the bank action first and fall back to "bank"
-- in the name. Deposit boxes are skipped because they cannot be opened as a bank.
function Banking.find(action)
    local candidates = API.ReadAllObjectsArray({ ObjectType, NpcType }, { -1 }, {}) or {}
    return Objects.nearest(candidates, function(candidate)
        return candidate.Action == action
    end) or Objects.nearest(candidates, function(candidate)
        return isBankName(candidate.Name)
    end)
end

function Banking.open(action)
    local bank = Banking.find(action)
    if bank == nil then
        return false
    end

    if bank.Type == NpcType then
        Interact:NPC(bank.Name, action)
        return true
    end
    Interact:Object(bank.Name, action)
    return true
end

-- Returns the first bank item, as { id, name, amount }, that matches. The bank
-- container is only filled once the bank has been opened.
function Banking.findItem(matches)
    for _, slot in ipairs(API.Container_Get_all(BankContainer) or {}) do
        if slot.item_id and slot.item_id >= 0 and (slot.item_stack or 0) > 0 then
            local data = Item:Get(slot.item_id)
            local item = { id = slot.item_id, name = data and data.name, amount = slot.item_stack }
            if matches(item) then
                return item
            end
        end
    end
    return nil
end

return Banking
