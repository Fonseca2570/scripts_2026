local API = require("api")
local Slib = require("slib")
API.SetDrawTrackedSkills(true)

local Config = {
    Bank = { x = 2889, y = 3533, z = 0 },
    FishingSpot = { x = 2899, y = 3471, z = 0 },
    AreaRadius = 20,
    BankAction = "Bank",
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

local function isNear(location)
    return Slib:IsPlayerInArea(location.x, location.y, location.z, Config.AreaRadius)
end

local function moveTo(location)
    Slib:MoveTo(location.x, location.y, location.z)
end

local function isRawFish(item)
    return item.name ~= nil and item.name:lower():find("^raw ") ~= nil
end

local function firstRawFish()
    local first, count = nil, 0
    for _, item in ipairs(Inventory:GetItems()) do
        if isRawFish(item) then
            first = first or item
            count = count + 1
        end
    end
    return first, count
end

-- Drop targets an item id, not a slot, so a drop sent before the game removes
-- the previous fish hits that same fish again. Wait for each drop to land.
local function dropOneRawFish(fish, count)
    Inventory:Drop(fish.id)
    for _ = 1, 10 do
        API.RandomSleep2(100, 50, 50)
        local _, remaining = firstRawFish()
        if remaining < count then
            return true
        end
    end
    return false
end

local function dropRawFish()
    local fish, count = firstRawFish()
    if fish == nil then
        return false
    end

    while fish ~= nil and API.Read_LoopyLoop() do
        if not dropOneRawFish(fish, count) then
            break
        end
        fish, count = firstRawFish()
    end
    return true
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

local function nearestObject(objects, matches)
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

local ObjectType = 0
local NpcType = 1

local function isBankName(name)
    local lower = name and name:lower() or ""
    return lower:find("bank", 1, true) ~= nil and lower:find("deposit", 1, true) == nil
end

-- Banks have different names (Bank booth, Bank chest, Banker...) and can be
-- objects or NPCs, so look for the "Bank" action first and fall back to "bank"
-- in the name. Deposit boxes are skipped because they cannot be opened as a bank.
local function findBank()
    local candidates = API.ReadAllObjectsArray({ ObjectType, NpcType }, { -1 }, {}) or {}
    return nearestObject(candidates, function(candidate)
        return candidate.Action == Config.BankAction
    end) or nearestObject(candidates, function(candidate)
        return isBankName(candidate.Name)
    end)
end

local function openBank()
    local bank = findBank()
    if bank == nil then
        State.Status = "No bank found"
        return
    end

    if bank.Type == NpcType then
        Interact:NPC(bank.Name, Config.BankAction)
        return
    end
    Interact:Object(bank.Name, Config.BankAction)
end

local function hasSupplies()
    return Config.InfiniteSupplies or Config.RequiredItem == "" or Inventory:Contains(Config.RequiredItem)
end

local function indexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then
            return i - 1
        end
    end
    return 0
end

local function drawTile(label, tile)
    ImGui.Text(label)
    ImGui.PushItemWidth(90)
    for _, axis in ipairs({ "x", "y", "z" }) do
        local changed, value = ImGui.InputInt(axis .. "##" .. label, tile[axis], 0, 0)
        if changed then
            tile[axis] = value
        end
        if axis ~= "z" then
            ImGui.SameLine(0, 6)
        end
    end
    ImGui.PopItemWidth()

    if ImGui.Button("Set to my position##" .. label) then
        local coord = API.PlayerCoord()
        tile.x, tile.y, tile.z = coord.x, coord.y, coord.z
    end
end

local function drawText(label, value)
    local changed, text = ImGui.InputText(label, value)
    if changed then
        return text
    end
    return value
end

local function copyTile(tile)
    return { x = tile.x, y = tile.y, z = tile.z }
end

local function setFishingAction(action)
    Config.FishingAction = action
    Config.RequiredItem = RequiredItems[action] or ""
end

local function applyLocation(location)
    Config.FishingSpot = copyTile(location.FishingSpot)
    setFishingAction(location.FishingAction)
    Config.PowerFish = location.PowerFish
    if location.Bank then
        Config.Bank = copyTile(location.Bank)
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
    drawTile("Fishing spot", Config.FishingSpot)
    Config.FishingNPC = drawText("Spot name", Config.FishingNPC)

    local changed, index = ImGui.Combo("Type", indexOf(FishingActions, Config.FishingAction), FishingActions)
    if changed then
        setFishingAction(FishingActions[index + 1])
    end

    local infiniteChanged, infinite = ImGui.Checkbox("Infinite bait / feathers", Config.InfiniteSupplies)
    if infiniteChanged then
        Config.InfiniteSupplies = infinite
    end
    if not Config.InfiniteSupplies then
        Config.RequiredItem = drawText("Required item", Config.RequiredItem)
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
    drawTile("Bank", Config.Bank)
    Config.BankAction = drawText("Action", Config.BankAction)
end

local function drawControls()
    ImGui.Separator()
    local changed, radius = ImGui.InputInt("Arrival radius", Config.AreaRadius, 1, 5)
    if changed then
        Config.AreaRadius = math.max(1, radius)
    end

    if ImGui.Button(State.Running and "Pause" or "Start", 120, 26) then
        State.Running = not State.Running
        State.Status = State.Running and "Starting" or "Paused"
    end
    ImGui.SameLine(0, 12)
    ImGui.Text("Status: " .. State.Status)
end

local function drawGui()
    ImGui.SetNextWindowSize(360, 0, ImGuiCond.Always)
    ImGui.SetNextWindowPos(60, 60, ImGuiCond.FirstUseEver)

    local open, visible = ImGui.Begin("Fisher###Fisher", true)
    if visible then
        local ok, err = pcall(function()
            drawLocation()
            drawFishing()
            drawMode()
            drawBank()
            drawControls()
        end)
        if not ok then
            ImGui.TextColored(1.0, 0.3, 0.3, 1.0, "GUI error: " .. tostring(err))
        end
    end
    ImGui.End()

    if not open then
        API.Write_LoopyLoop(false)
    end
end

if type(ClearRender) == "function" then
    ClearRender()
end

if type(DrawImGui) == "function" then
    DrawImGui(drawGui)
end

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
            if dropRawFish() then
                goto continue
            end
        end

        if not isNear(Config.Bank) then
            State.Status = "Walking to bank"
            moveTo(Config.Bank)
            goto continue
        end

        State.Status = "Banking"
        if Bank:IsOpen() then
            depositRawFish()
            goto continue
        end

        openBank()
        goto continue
    end

    if not isNear(Config.FishingSpot) then
        State.Status = "Walking to fishing spot"
        moveTo(Config.FishingSpot)
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
