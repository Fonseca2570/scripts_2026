local API = require("api")
local Objects = require("utils.objects")

local Banking = {}

local ObjectType = 0
local NpcType = 1
local DecorType = 12
local EscapeKey = 0x1B
local BankContainer = 95
-- Some deposit boxes, like Wendlewick's, have this right-click option, which
-- deposits the fish without opening the box.
local DepositAllFishAction = "Deposit all fish"

-- Bank chests open with "Use", bank booths and bankers with "Bank". Bankers are
-- NPCs, sometimes with a prefix like "Gnome banker". Deposit boxes are not
-- listed because they cannot be opened as a bank.
local Types = {
    { Name = "Bank booth", Action = "Bank" },
    { Name = "Bank chest", Action = "Use" },
    { Name = "Banker", Action = "Bank" },
}

Banking.TypeNames = { "Auto" }
for _, bankType in ipairs(Types) do
    Banking.TypeNames[#Banking.TypeNames + 1] = bankType.Name
end

local function typeOf(name)
    local lower = (name or ""):lower()
    for _, bankType in ipairs(Types) do
        if lower:find(bankType.Name:lower(), 1, true) ~= nil then
            return bankType
        end
    end
    return nil
end

-- Returns the nearest bank of the given type, or of any type for "Auto", and
-- its type. Some bank chests, like Burthorpe's, are decor objects.
function Banking.find(typeName)
    local candidates = API.ReadAllObjectsArray({ ObjectType, NpcType, DecorType }, { -1 }, {}) or {}
    local bank = Objects.nearest(candidates, function(candidate)
        local bankType = typeOf(candidate.Name)
        return bankType ~= nil and (typeName == "Auto" or bankType.Name == typeName)
    end)
    if bank == nil then
        return nil, nil
    end
    return bank, typeOf(bank.Name)
end

function Banking.open(typeName)
    local bank, bankType = Banking.find(typeName)
    if bank == nil then
        return false
    end

    if bank.Type == NpcType then
        Interact:NPC(bank.Name, bankType.Action)
        return true
    end
    Interact:Object(bank.Name, bankType.Action)
    return true
end

local function isDepositBox(object)
    return (object.Name or ""):lower():find("deposit box", 1, true) ~= nil
end

-- Uses "Deposit all fish" on the nearest deposit box within range tiles of the
-- player. Returns false when there is none or the box has no such option.
function Banking.depositAllFish(range)
    local candidates = API.ReadAllObjectsArray({ ObjectType, DecorType }, { -1 }, {}) or {}
    local box = Objects.nearest(candidates, function(candidate)
        return isDepositBox(candidate) and API.Dist_FLP(candidate.Tile_XYZ) <= range
    end)
    if box == nil then
        return false
    end

    return Interact:Object(box.Name, DepositAllFishAction, box.Tile_XYZ, 1) == true
end

-- The API has no close-bank call, so press Escape like a player would. An open
-- bank blocks the inventory, so close it after withdrawing.
function Banking.close()
    if not Bank:IsOpen() then
        return true
    end

    API.KeyboardPress2(EscapeKey, 60, 100)
    for _ = 1, 10 do
        API.RandomSleep2(100, 50, 50)
        if not Bank:IsOpen() then
            return true
        end
    end
    return false
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
