local API = require("api")
local Banking = require("utils.banking")
local Gui = require("utils.gui")
local Items = require("utils.items")
local Objects = require("utils.objects")
local Player = require("utils.player")
API.SetDrawTrackedSkills(true)

local Config = {
    BankType = "Auto",
    Permanent = false,
    CollectSpirits = true,
}

-- Logs and Firemaking levels from the RS3 Wiki, highest first.
local Logs = {
    { Name = "Elder logs", Level = 90 },
    { Name = "Cursed magic logs", Level = 82 },
    { Name = "Magic logs", Level = 75 },
    { Name = "Yew logs", Level = 60 },
    { Name = "Eucalyptus logs", Level = 58 },
    { Name = "Mahogany logs", Level = 50 },
    { Name = "Acadia logs", Level = 47 },
    { Name = "Maple logs", Level = 45 },
    { Name = "Arctic pine logs", Level = 42 },
    { Name = "Teak logs", Level = 35 },
    { Name = "Willow logs", Level = 30 },
    { Name = "Oak logs", Level = 15 },
    { Name = "Logs", Level = 1 },
}

local Modes = { "Make bonfire", "Permanent bonfire" }

-- Add-logs actions from the RS3 Wiki. Permanent bonfires (Yeti Town,
-- Prifddinas, Max Guild) and the Menaphos fire pit also have "Cook on", and
-- players can make it the left-click option, so "Add logs to" is always named.
-- Player-made fires only have "Use", so logs are used on them instead. Either
-- way the bonfire keeps burning the backpack's logs of that type.
local FireActions = {
    ["fire"] = {},
    ["bonfire"] = { "Add logs to" },
    ["fire pit"] = { "Add logs to" },
}
local FireSearchRadius = 15

-- A fire spirit sometimes appears at the bonfire for one minute and only its
-- player can see it. "fire spirit" also matches the divine fire spirit.
local NpcType = 1
local LightOption = 2
local UseOnAction = 0x24

local LogLevels = {}
for _, log in ipairs(Logs) do
    LogLevels[log.Name:lower()] = log.Level
end

local State = {
    Running = false,
    Status = "Paused",
    Log = "",
}

local function firemakingLevel()
    return API.XPLevelTable(API.GetSkillXP("FIREMAKING"))
end

local function isBurnable(item)
    local level = LogLevels[Items.lowerName(item)]
    return level ~= nil and level <= firemakingLevel()
end

local function findFire()
    local objects = API.ReadAllObjectsArray({ 0, 12 }, { -1 }, {}) or {}
    return Objects.nearest(objects, function(object)
        return FireActions[(object.Name or ""):lower()] ~= nil and API.Dist_FLP(object.Tile_XYZ) <= FireSearchRadius
    end)
end

local function collectSpirit()
    if not Config.CollectSpirits then
        return false
    end

    local npcs = API.ReadAllObjectsArray({ NpcType }, { -1 }, {}) or {}
    local spirit = Objects.nearest(npcs, function(npc)
        return (npc.Name or ""):lower():find("fire spirit", 1, true) ~= nil
    end)
    if spirit == nil then
        return false
    end

    Interact:NPC(spirit.Name, spirit.Action)
    return true
end

local function addToFire(log, fire)
    for _, action in ipairs(FireActions[fire.Name:lower()]) do
        if Interact:Object(fire.Name, action) then
            return
        end
    end

    Inventory:Use(log.id)
    API.RandomSleep2(200, 50, 50)
    API.DoAction_Object1(UseOnAction, API.GeneralObject_route_useon, { fire.Id }, 50)
end

-- "Light" is the second option on logs and uses the tool belt's tinderbox.
local function light(log)
    Inventory:DoAction(log.id, LightOption, API.OFF_ACT_GeneralInterface_route)
end

local function bestLogInBank()
    local level = firemakingLevel()
    for _, log in ipairs(Logs) do
        if log.Level <= level then
            local found = Banking.findItem(function(item)
                return item.name == log.Name
            end)
            if found ~= nil then
                return found
            end
        end
    end
    return nil
end

local function withdrawLogs()
    Bank:DepositInventory()
    API.RandomSleep2(300, 100, 100)

    local log = bestLogInBank()
    if log == nil then
        return false
    end

    Bank:WithdrawAll(log.id)
    for _ = 1, 10 do
        API.RandomSleep2(100, 50, 50)
        if Items.find(isBurnable) ~= nil then
            break
        end
    end
    Banking.close()
    return true
end

-- Returns the status to show. A permanent bonfire is used as it is, otherwise
-- a fire is lit where the player stands first.
local function burn(log)
    local fire = findFire()
    if fire ~= nil then
        addToFire(log, fire)
        Player.waitUntilBusy()
        return "Burning " .. log.name
    end

    if Config.Permanent then
        return "No bonfire found"
    end

    light(log)
    Player.waitUntilBusy()
    return "Lighting fire"
end

local function drawFire()
    ImGui.SeparatorText("Fire")
    local changed, index = ImGui.Combo("Mode", Config.Permanent and 1 or 0, Modes)
    if changed then
        Config.Permanent = index == 1
    end
    ImGui.Text("Firemaking level: " .. firemakingLevel())
    ImGui.Text("Logs: " .. (State.Log ~= "" and State.Log or "-"))
    Config.CollectSpirits = Gui.checkbox("Collect fire spirits", Config.CollectSpirits)

    if Config.Permanent then
        return
    end
    ImGui.Text("Lights the fire where you stand. Fires can't")
    ImGui.Text("be lit right next to a bank.")
end

local function drawBank()
    ImGui.SeparatorText("Bank")
    Config.BankType = Gui.combo("Bank type", Config.BankType, Banking.TypeNames)
end

Gui.show("Firemaker", function()
    drawFire()
    drawBank()
    Gui.controls(Config, State)
end)

API.Write_LoopyLoop(true)

while API.Read_LoopyLoop() do

    if not State.Running then
        API.RandomSleep2(200, 100, 100)
        goto continue
    end

    if API.ReadPlayerMovin2() then
        API.RandomSleep2(50, 100, 100)
        goto continue
    end

    if collectSpirit() then
        State.Status = "Collecting fire spirit"
        API.RandomSleep2(600, 200, 200)
        goto continue
    end

    if API.CheckAnim(10) or API.isProcessing() then
        API.RandomSleep2(50, 100, 100)
        goto continue
    end

    do
        local log = Items.find(isBurnable)
        if log ~= nil then
            State.Log = log.name
            State.Status = burn(log)
            goto continue
        end
    end

    if Bank:IsOpen() then
        State.Status = "Banking"
        if not withdrawLogs() then
            State.Running = false
            State.Status = "Nothing left to burn"
            API.Write_LoopyLoop(false)
        end
        goto continue
    end

    State.Status = "Opening bank"
    if not Banking.open(Config.BankType) then
        State.Status = "No bank found"
    end

    ::continue::
    API.RandomSleep2(100, 200, 200)
end
