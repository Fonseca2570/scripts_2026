local API = require("api")
local Slib = require("slib")
API.SetDrawTrackedSkills(true)

local Config = {
    Bank = { x = 3093, y = 3244, z = 0 },
    TreeSpot = { x = 3087, y = 3231, z = 0 },
    AreaRadius = 20,
    BankAction = "Bank",
    Tree = "Willow",
    PowerChop = false,
    ByLevel = false,
    UseWoodBox = true,
    PickUpNests = true,
}

-- Object names, levels and actions from the RS3 Wiki. Maple's object is
-- "Maple Tree" and Acadia uses "Cut down" instead of "Chop down".
local Trees = {
    { Name = "Tree", Level = 1, Action = "Chop down" },
    { Name = "Oak", Level = 10, Action = "Chop down" },
    { Name = "Willow", Level = 20, Action = "Chop down" },
    { Name = "Teak", Level = 30, Action = "Chop down" },
    { Name = "Maple Tree", Level = 40, Action = "Chop down" },
    { Name = "Acadia tree", Level = 50, Action = "Cut down" },
    { Name = "Eucalyptus tree", Level = 58, Action = "Chop down" },
    { Name = "Mahogany", Level = 60, Action = "Chop down" },
    { Name = "Yew", Level = 70, Action = "Chop down" },
    { Name = "Magic tree", Level = 80, Action = "Chop down" },
    { Name = "Elder tree", Level = 90, Action = "Chop down" },
}

local Modes = { "Banking", "Power chopping" }
local TreeModes = { "Fixed tree", "By level" }

-- Tree and bank tiles from the RS3 Wiki. Each location has one tree type, so
-- "By level" picks the highest location the player's level allows.
local Locations = {
    {
        Name = "Draynor oaks",
        Tree = "Oak",
        TreeSpot = { x = 3106, y = 3247, z = 0 },
        Bank = { x = 3093, y = 3244, z = 0 },
    },
    {
        Name = "Draynor willows",
        Tree = "Willow",
        TreeSpot = { x = 3087, y = 3231, z = 0 },
        Bank = { x = 3093, y = 3244, z = 0 },
    },
    {
        Name = "Seers' Village maples",
        Tree = "Maple Tree",
        TreeSpot = { x = 2729, y = 3481, z = 0 },
        Bank = { x = 2725, y = 3492, z = 0 },
    },
    {
        Name = "Oo'glog eucalyptus",
        Tree = "Eucalyptus tree",
        TreeSpot = { x = 2408, y = 2818, z = 0 },
        Bank = { x = 2412, y = 2827, z = 0 },
    },
    {
        Name = "Edgeville yews",
        Tree = "Yew",
        TreeSpot = { x = 3085, y = 3480, z = 0 },
        Bank = { x = 3095, y = 3494, z = 0 },
    },
    {
        Name = "Sorcerer's Tower magics",
        Tree = "Magic tree",
        TreeSpot = { x = 2698, y = 3398, z = 0 },
        Bank = { x = 2674, y = 3405, z = 0 },
    },
}

local TreeNames = {}
for i, tree in ipairs(Trees) do
    TreeNames[i] = tree.Name
end

local LocationNames = {}
for i, location in ipairs(Locations) do
    LocationNames[i] = location.Name
end

local State = {
    Running = false,
    Status = "Paused",
    Location = 1,
    WoodBoxFull = false,
    NestRetryAt = 0,
}

local NestRetryDelay = 30

local function isNear(location)
    return Slib:IsPlayerInArea(location.x, location.y, location.z, Config.AreaRadius)
end

local function moveTo(location)
    Slib:MoveTo(location.x, location.y, location.z)
end

local function woodcuttingLevel()
    return API.XPLevelTable(API.GetSkillXP("WOODCUTTING"))
end

local function findTree(name)
    for _, tree in ipairs(Trees) do
        if tree.Name == name then
            return tree
        end
    end
    return Trees[1]
end

local function lowerName(item)
    return item.name and item.name:lower() or ""
end

local function isLog(item)
    return lowerName(item):find("logs$") ~= nil
end

local function isNest(item)
    return lowerName(item):find("bird's nest", 1, true) ~= nil
end

local function isWoodBox(item)
    return lowerName(item):find("wood box", 1, true) ~= nil
end

local function findItem(matches)
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
-- the previous log hits that same log again. Wait for each drop to land.
local function dropOneLog(log, count)
    Inventory:Drop(log.id)
    for _ = 1, 10 do
        API.RandomSleep2(100, 50, 50)
        local _, remaining = findItem(isLog)
        if remaining < count then
            return true
        end
    end
    return false
end

local function dropLogs()
    local log, count = findItem(isLog)
    if log == nil then
        return false
    end

    while log ~= nil and API.Read_LoopyLoop() do
        if not dropOneLog(log, count) then
            break
        end
        log, count = findItem(isLog)
    end
    return true
end

-- Fill is the wood box's first option. A fill that moves no logs means the box
-- is full, so stop trying until it is emptied at the bank.
local function fillWoodBox()
    if not Config.UseWoodBox or State.WoodBoxFull then
        return false
    end

    local box = findItem(isWoodBox)
    if box == nil then
        return false
    end

    local _, before = findItem(isLog)
    API.DoAction_Inventory1(box.id, 0, 1, API.OFF_ACT_GeneralInterface_route)
    for _ = 1, 15 do
        API.RandomSleep2(100, 50, 50)
        local _, after = findItem(isLog)
        if after < before then
            return true
        end
    end

    State.WoodBoxFull = true
    return false
end

local function pickUpNests()
    if not Config.PickUpNests or os.time() < State.NestRetryAt then
        return false
    end

    local ids = {}
    for _, item in ipairs(API.ReadAllObjectsArray({ 3 }, { -1 }, {}) or {}) do
        if isNest({ name = item.Name }) then
            ids[#ids + 1] = item.Id
        end
    end
    if #ids == 0 then
        return false
    end

    -- A nest that cannot be reached would be retried forever, so give up on
    -- nests for a while when one does not reach the inventory.
    local _, before = findItem(isNest)
    API.DoAction_Loot_o(ids, Config.AreaRadius, API.PlayerCoordfloat(), Config.AreaRadius)
    for _ = 1, 20 do
        API.RandomSleep2(150, 50, 50)
        local _, after = findItem(isNest)
        if after > before then
            return true
        end
    end

    State.NestRetryAt = os.time() + NestRetryDelay
    return false
end

local function depositAtBank()
    if Config.UseWoodBox and findItem(isWoodBox) ~= nil then
        Bank:WoodBoxDepositLogs()
        State.WoodBoxFull = false
    end

    local logs, others = {}, {}
    for _, item in ipairs(Inventory:GetItems()) do
        if isLog(item) or isNest(item) then
            logs[#logs + 1] = item.id
        elseif not isWoodBox(item) then
            others[#others + 1] = item.id
        end
    end

    -- With no logs or nests the inventory is full of something else, so bank
    -- that instead, but never the wood box.
    if #logs > 0 then
        Bank:DepositAll(logs)
        return
    end
    if #others > 0 then
        Bank:DepositAll(others)
    end
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

local function copyTile(tile)
    return { x = tile.x, y = tile.y, z = tile.z }
end

local function applyLocation(index)
    local location = Locations[index]
    State.Location = index
    Config.Tree = location.Tree
    Config.TreeSpot = copyTile(location.TreeSpot)
    Config.Bank = copyTile(location.Bank)
end

local function bestLocationForLevel(level)
    local best = nil
    for i, location in ipairs(Locations) do
        if findTree(location.Tree).Level <= level then
            best = i
        end
    end
    return best
end

-- In "By level" mode the location follows the player's level, so a level-up
-- sends the script to the next tree the next time it goes to chop.
local function followLevel()
    if not Config.ByLevel then
        return true
    end

    -- Below the first location's level, chop normal trees around it instead.
    local best = bestLocationForLevel(woodcuttingLevel())
    if best == nil then
        if State.Location ~= 1 or Config.Tree ~= "Tree" then
            applyLocation(1)
            Config.Tree = "Tree"
        end
        return true
    end
    if best ~= State.Location or Config.Tree ~= Locations[best].Tree then
        applyLocation(best)
    end
    return true
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

local function drawCheckbox(label, value)
    local changed, checked = ImGui.Checkbox(label, value)
    if changed then
        return checked
    end
    return value
end

local function drawTreeMode()
    local changed, index = ImGui.Combo("Tree mode", Config.ByLevel and 1 or 0, TreeModes)
    if changed then
        Config.ByLevel = index == 1
    end

    if Config.ByLevel then
        ImGui.Text("Level " .. woodcuttingLevel() .. ": " .. Locations[State.Location].Name)
        return
    end

    local locationChanged, location = ImGui.Combo("Location", State.Location - 1, LocationNames)
    if locationChanged then
        applyLocation(location + 1)
    end
end

local function drawTrees()
    ImGui.SeparatorText("Trees")
    drawTreeMode()
    if Config.ByLevel then
        return
    end

    drawTile("Tree spot", Config.TreeSpot)
    local changed, index = ImGui.Combo("Tree", indexOf(TreeNames, Config.Tree), TreeNames)
    if changed then
        Config.Tree = TreeNames[index + 1]
    end
end

local function drawMode()
    ImGui.SeparatorText("When inventory is full")
    local changed, index = ImGui.Combo("Mode", Config.PowerChop and 1 or 0, Modes)
    if changed then
        Config.PowerChop = index == 1
    end
    Config.UseWoodBox = drawCheckbox("Fill wood box", Config.UseWoodBox)
    Config.PickUpNests = drawCheckbox("Pick up bird's nests", Config.PickUpNests)
end

local function drawBank()
    if Config.PowerChop or Config.ByLevel then
        return
    end

    ImGui.SeparatorText("Bank")
    drawTile("Bank", Config.Bank)
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

    local open, visible = ImGui.Begin("Woodcutter###Woodcutter", true)
    if visible then
        local ok, err = pcall(function()
            drawTrees()
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

applyLocation(2)

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

    if not Inventory:IsFull() and pickUpNests() then
        State.Status = "Picking up nest"
        goto continue
    end

    if Inventory:IsFull() then
        if not Config.PowerChop and fillWoodBox() then
            State.Status = "Filling wood box"
            goto continue
        end

        if Config.PowerChop then
            State.Status = "Dropping logs"
            if dropLogs() then
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
            depositAtBank()
            goto continue
        end

        openBank()
        goto continue
    end

    if not followLevel() then
        goto continue
    end

    if not isNear(Config.TreeSpot) then
        State.Status = "Walking to trees"
        moveTo(Config.TreeSpot)
        goto continue
    end

    State.Status = "Chopping " .. Config.Tree
    Interact:Object(Config.Tree, findTree(Config.Tree).Action)

    ::continue::
    API.RandomSleep2(100, 200, 200)
end
