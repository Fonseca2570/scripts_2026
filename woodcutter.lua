local API = require("api")
local Banking = require("utils.banking")
local Gui = require("utils.gui")
local Items = require("utils.items")
local Movement = require("utils.movement")
API.SetDrawTrackedSkills(true)

local Config = {
    Bank = { x = 3093, y = 3244, z = 0 },
    TreeSpot = { x = 3087, y = 3231, z = 0 },
    AreaRadius = 20,
    BankType = "Auto",
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
-- "By level" picks the highest location the player's level allows. The Wiki has
-- no tiles for normal trees, so they use the Draynor oak tile and the nearest
-- "Tree" around it.
local Locations = {
    {
        Name = "Draynor normal trees",
        Tree = "Tree",
        TreeSpot = { x = 3106, y = 3247, z = 0 },
        Bank = { x = 3093, y = 3244, z = 0 },
    },
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

local function isLog(item)
    return Items.lowerName(item):find("logs$") ~= nil
end

local function isNest(item)
    return Items.lowerName(item):find("bird's nest", 1, true) ~= nil
end

local function isWoodBox(item)
    return Items.lowerName(item):find("wood box", 1, true) ~= nil
end

-- A fill that moves no logs means the box is full, so stop trying until it is
-- emptied at the bank.
local function fillWoodBox()
    if not Config.UseWoodBox or State.WoodBoxFull then
        return false
    end

    local box = Items.find(isWoodBox)
    if box == nil then
        return false
    end

    if Items.fill(box, isLog) then
        return true
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
    local _, before = Items.find(isNest)
    API.DoAction_Loot_o(ids, Config.AreaRadius, API.PlayerCoordfloat(), Config.AreaRadius)
    for _ = 1, 20 do
        API.RandomSleep2(150, 50, 50)
        local _, after = Items.find(isNest)
        if after > before then
            return true
        end
    end

    State.NestRetryAt = os.time() + NestRetryDelay
    return false
end

local function depositAtBank()
    if Config.UseWoodBox and Items.find(isWoodBox) ~= nil then
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

local function applyLocation(index)
    local location = Locations[index]
    State.Location = index
    Config.Tree = location.Tree
    Config.TreeSpot = Movement.copyTile(location.TreeSpot)
    Config.Bank = Movement.copyTile(location.Bank)
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

    local best = bestLocationForLevel(woodcuttingLevel())
    if best ~= State.Location or Config.Tree ~= Locations[best].Tree then
        applyLocation(best)
    end
    return true
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

    Gui.tile("Tree spot", Config.TreeSpot)
    local changed, index = ImGui.Combo("Tree", Gui.indexOf(TreeNames, Config.Tree), TreeNames)
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
    Config.UseWoodBox = Gui.checkbox("Fill wood box", Config.UseWoodBox)
    Config.PickUpNests = Gui.checkbox("Pick up bird's nests", Config.PickUpNests)
end

local function drawBank()
    if Config.PowerChop then
        return
    end

    ImGui.SeparatorText("Bank")
    Config.BankType = Gui.combo("Bank type", Config.BankType, Banking.TypeNames)
    if not Config.ByLevel then
        Gui.tile("Bank", Config.Bank)
    end
end

applyLocation(3)

Gui.show("Woodcutter", function()
    drawTrees()
    drawMode()
    drawBank()
    Gui.controls(Config, State)
end)

API.Write_LoopyLoop(true)

while API.Read_LoopyLoop() do
    Gui.update()

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
            if Items.dropAll(isLog) then
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
            depositAtBank()
            goto continue
        end

        if not Banking.open(Config.BankType) then
            State.Status = "No bank found"
        end
        goto continue
    end

    if not followLevel() then
        goto continue
    end

    if not Movement.isNear(Config.TreeSpot, Config.AreaRadius) then
        State.Status = "Walking to trees"
        Movement.moveTo(Config.TreeSpot)
        goto continue
    end

    State.Status = "Chopping " .. Config.Tree
    Interact:Object(Config.Tree, findTree(Config.Tree).Action)

    ::continue::
    API.RandomSleep2(100, 200, 200)
end
