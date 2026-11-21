local API = require("api")
local Slib = require("slib")
local Banking = require("utils.banking")
local Gui = require("utils.gui")
local Items = require("utils.items")
local Movement = require("utils.movement")
API.SetDrawTrackedSkills(true)

local Config = {
    Bank = { x = 2889, y = 3533, z = 0 },
    FishingSpot = { x = 2899, y = 3471, z = 0 },
    AreaRadius = 20,
    BankType = "Auto",
    FishingNPC = "Fishing spot",
    FishingAction = "Cage",
    PowerFish = false,
    InfiniteSupplies = false,
    RequiredItem = "",
}

local FishingActions = { "Cage", "Harpoon", "Net", "Big net", "Bait", "Lure" }
local Modes = { "Banking", "Power fishing" }

-- Cage, harpoon and net tools live on the tool belt, so only bait and feathers
-- are used up and need to be in the inventory.
local RequiredItems = {
    Bait = "Fishing bait",
    Lure = "Feather",
}

-- Fishing spot and bank tiles from the RS3 Wiki, except Burthorpe. Fishing spot
-- tiles are in the water, so MoveTo walks to the shore and stops there.
-- Barbarian Village banks at Edgeville.
local Locations = {
    {
        Name = "Burthorpe",
        FishingSpot = { x = 2899, y = 3471, z = 0 },
        FishingAction = "Cage",
        Bank = { x = 2889, y = 3533, z = 0 },
        PowerFish = false,
    },
    {
        Name = "Catherby",
        FishingSpot = { x = 2844, y = 3429, z = 0 },
        FishingAction = "Cage",
        Bank = { x = 2795, y = 3440, z = 0 },
        PowerFish = false,
    },
    {
        Name = "Fishing Guild",
        FishingSpot = { x = 2605, y = 3421, z = 0 },
        FishingAction = "Cage",
        Bank = { x = 2585, y = 3422, z = 0 },
        PowerFish = false,
    },
    {
        Name = "Draynor Village",
        FishingSpot = { x = 3086, y = 3227, z = 0 },
        FishingAction = "Net",
        Bank = { x = 3093, y = 3244, z = 0 },
        PowerFish = false,
    },
    {
        Name = "Barbarian Village",
        FishingSpot = { x = 3104, y = 3424, z = 0 },
        FishingAction = "Lure",
        Bank = { x = 3095, y = 3494, z = 0 },
        PowerFish = true,
    },
}

local LocationNames = {}
for i, location in ipairs(Locations) do
    LocationNames[i] = location.Name
end

local State = {
    Running = false,
    Status = "Paused",
    Location = 0,
}

local function isRawFish(item)
    return Items.lowerName(item):find("^raw ") ~= nil
end

local function depositRawFish()
    local ids = {}
    for _, item in ipairs(Inventory:GetItems()) do
        if isRawFish(item) then
            ids[#ids + 1] = item.id
        end
    end

    if #ids == 0 then
        Bank:DepositInventory()
        return
    end
    Bank:DepositAll(ids)
end

local function hasSupplies()
    return Config.InfiniteSupplies or Config.RequiredItem == "" or Inventory:Contains(Config.RequiredItem)
end

local function setFishingAction(action)
    Config.FishingAction = action
    Config.RequiredItem = RequiredItems[action] or ""
end

local function applyLocation(location)
    Config.FishingSpot = Movement.copyTile(location.FishingSpot)
    setFishingAction(location.FishingAction)
    Config.PowerFish = location.PowerFish
    if location.Bank then
        Config.Bank = Movement.copyTile(location.Bank)
    end
end

local function drawLocation()
    local changed, index = ImGui.Combo("Location", State.Location, LocationNames)
    if changed then
        State.Location = index
        applyLocation(Locations[index + 1])
    end
end

local function drawFishing()
    ImGui.SeparatorText("Fishing")
    Gui.tile("Fishing spot", Config.FishingSpot)
    Config.FishingNPC = Gui.text("Spot name", Config.FishingNPC)

    local changed, index = ImGui.Combo("Type", Gui.indexOf(FishingActions, Config.FishingAction), FishingActions)
    if changed then
        setFishingAction(FishingActions[index + 1])
    end

    Config.InfiniteSupplies = Gui.checkbox("Infinite bait / feathers", Config.InfiniteSupplies)
    if not Config.InfiniteSupplies then
        Config.RequiredItem = Gui.text("Required item", Config.RequiredItem)
    end
end

local function drawMode()
    ImGui.SeparatorText("When inventory is full")
    local changed, index = ImGui.Combo("Mode", Config.PowerFish and 1 or 0, Modes)
    if changed then
        Config.PowerFish = index == 1
    end
end

local function drawBank()
    if Config.PowerFish then
        return
    end

    ImGui.SeparatorText("Bank")
    Gui.tile("Bank", Config.Bank)
    Config.BankType = Gui.combo("Bank type", Config.BankType, Banking.TypeNames)
end

Gui.show("Fisher", function()
    drawLocation()
    drawFishing()
    drawMode()
    drawBank()
    Gui.controls(Config, State)
end)

API.Write_LoopyLoop(true)

while API.Read_LoopyLoop() do

    if not State.Running then
        API.RandomSleep2(200, 100, 100)
        goto continue
    end

    if API.CheckAnim(10) or API.isProcessing() or API.ReadPlayerMovin2() then
        API.RandomSleep2(50, 100, 100)
        goto continue
    end

    if Inventory:IsFull() then
        if Config.PowerFish then
            State.Status = "Dropping fish"
            if Items.dropAll(isRawFish) then
                goto continue
            end
        end

        if not Movement.isNear(Config.Bank, Config.AreaRadius) then
            State.Status = "Walking to bank"
            Movement.moveTo(Config.Bank)
            goto continue
        end

        State.Status = "Banking"
        if Bank:IsOpen() then
            depositRawFish()
            goto continue
        end

        if not Banking.open(Config.BankType) then
            State.Status = "No bank found"
        end
        goto continue
    end

    if not Movement.isNear(Config.FishingSpot, Config.AreaRadius) then
        State.Status = "Walking to fishing spot"
        Movement.moveTo(Config.FishingSpot)
        goto continue
    end

    if not hasSupplies() then
        State.Status = "Out of " .. Config.RequiredItem
        Slib:Info("[Fisher] Out of " .. Config.RequiredItem .. ", stopping")
        break
    end

    State.Status = "Fishing"
    Interact:NPC(Config.FishingNPC, Config.FishingAction)

    ::continue::
    API.RandomSleep2(100, 200, 200)
end
