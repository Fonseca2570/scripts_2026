local API = require("api")
local Banking = require("utils.banking")
local Gui = require("utils.gui")
local Items = require("utils.items")
local Movement = require("utils.movement")
API.SetDrawTrackedSkills(true)

local Config = {
    Bank = { x = 3270, y = 3168, z = 0 },
    RockSpot = { x = 3229, y = 3148, z = 0 },
    AreaRadius = 20,
    BankType = "Auto",
    Rock = "Copper rock",
    PowerMine = false,
    ByLevel = false,
    UseOreBox = true,
    UseRockertunities = true,
}

-- Rock and ore names and levels from the RS3 Wiki.
local Rocks = {
    { Name = "Copper rock", Ore = "Copper ore", Level = 1 },
    { Name = "Tin rock", Ore = "Tin ore", Level = 1 },
    { Name = "Iron rock", Ore = "Iron ore", Level = 10 },
    { Name = "Silver rock", Ore = "Silver ore", Level = 20 },
    { Name = "Coal rock", Ore = "Coal", Level = 20 },
    { Name = "Mithril rock", Ore = "Mithril ore", Level = 30 },
    { Name = "Adamantite rock", Ore = "Adamantite ore", Level = 40 },
    { Name = "Luminite rock", Ore = "Luminite", Level = 40 },
    { Name = "Gold rock", Ore = "Gold ore", Level = 40 },
    { Name = "Runite rock", Ore = "Runite ore", Level = 50 },
    { Name = "Orichalcite rock", Ore = "Orichalcite ore", Level = 60 },
    { Name = "Drakolith rock", Ore = "Drakolith", Level = 60 },
    { Name = "Necrite rock", Ore = "Necrite ore", Level = 70 },
    { Name = "Phasmatite rock", Ore = "Phasmatite", Level = 70 },
    { Name = "Banite rock", Ore = "Banite ore", Level = 80 },
}

local Modes = { "Banking", "Power mining" }
local RockModes = { "Fixed rock", "By level" }

-- Rock and bank tiles from the RS3 Wiki, only mines that can be walked to.
-- Each location mines one rock type, so "By level" picks the highest location
-- the player's level allows. The Varrock tiles are the middle of the mine.
local Locations = {
    {
        Name = "Lumbridge SE copper",
        Rock = "Copper rock",
        RockSpot = { x = 3229, y = 3148, z = 0 },
        Bank = { x = 3270, y = 3168, z = 0 },
    },
    {
        Name = "Lumbridge SE tin",
        Rock = "Tin rock",
        RockSpot = { x = 3225, y = 3146, z = 0 },
        Bank = { x = 3270, y = 3168, z = 0 },
    },
    {
        Name = "Lumbridge SW iron",
        Rock = "Iron rock",
        RockSpot = { x = 3145, y = 3149, z = 0 },
        Bank = { x = 3093, y = 3244, z = 0 },
    },
    {
        Name = "Falador west silver",
        Rock = "Silver rock",
        RockSpot = { x = 2907, y = 3346, z = 0 },
        Bank = { x = 2946, y = 3367, z = 0 },
    },
    {
        Name = "Falador west coal",
        Rock = "Coal rock",
        RockSpot = { x = 2904, y = 3344, z = 0 },
        Bank = { x = 2946, y = 3367, z = 0 },
    },
    {
        Name = "Varrock SE mithril",
        Rock = "Mithril rock",
        RockSpot = { x = 3287, y = 3363, z = 0 },
        Bank = { x = 3254, y = 3421, z = 0 },
    },
    {
        Name = "Al Kharid gold",
        Rock = "Gold rock",
        RockSpot = { x = 3295, y = 3287, z = 0 },
        Bank = { x = 3270, y = 3168, z = 0 },
    },
    {
        Name = "Varrock SE adamantite",
        Rock = "Adamantite rock",
        RockSpot = { x = 3287, y = 3363, z = 0 },
        Bank = { x = 3254, y = 3421, z = 0 },
    },
}

-- Rockertunity highlight ids and the stamina threshold come from community
-- mining scripts. Clicking a rock refills stamina, so click again when it runs low.
local RockertunityIds = { 7164, 7165 }
local LowStamina = 200
local StaminaLevel = 15
local MineAction = "Mine"

local RockNames = {}
for i, rock in ipairs(Rocks) do
    RockNames[i] = rock.Name
end

local LocationNames = {}
for i, location in ipairs(Locations) do
    LocationNames[i] = location.Name
end

local OreNames = {}
for _, rock in ipairs(Rocks) do
    OreNames[rock.Ore:lower()] = true
end

local State = {
    Running = false,
    Status = "Paused",
    Location = 1,
    OreBoxFull = false,
}

local function miningLevel()
    return API.XPLevelTable(API.GetSkillXP("MINING"))
end

local function findRock(name)
    for _, rock in ipairs(Rocks) do
        if rock.Name == name then
            return rock
        end
    end
    return Rocks[1]
end

local function isOre(item)
    return OreNames[Items.lowerName(item)] == true
end

local function isOreBox(item)
    return Items.lowerName(item):find("ore box", 1, true) ~= nil
end

local function fillOreBox()
    if not Config.UseOreBox or State.OreBoxFull then
        return false
    end

    local box = Items.find(isOreBox)
    if box == nil then
        return false
    end

    if Items.fill(box, isOre) then
        return true
    end
    State.OreBoxFull = true
    return false
end

-- Gems and other drops are banked with the ore, but never the ore box.
local function depositAtBank()
    if Items.find(isOreBox) ~= nil then
        Bank:OreBoxDepositOres()
        State.OreBoxFull = false
    end

    local ids = {}
    for _, item in ipairs(Inventory:GetItems()) do
        if item.id ~= nil and item.id >= 0 and not isOreBox(item) then
            ids[#ids + 1] = item.id
        end
    end
    if #ids > 0 then
        Bank:DepositAll(ids)
    end
end

-- A rockertunity highlights one rock near the one being mined. Clicking that
-- rock gives one much stronger hit.
local function mineRockertunity()
    if not Config.UseRockertunities then
        return false
    end

    for _, highlight in ipairs(API.GetAllObjArray1(RockertunityIds, 25, { 4 }) or {}) do
        if Interact:Object(Config.Rock, MineAction, highlight.Tile_XYZ, 1) then
            return true
        end
    end
    return false
end

local function mine()
    Interact:Object(Config.Rock, MineAction)
end

-- Stamina starts at Mining level 15. Below that, or when the bar is not shown,
-- the progress bar reads 0 or less and must not trigger a click every loop.
local function isStaminaLow()
    if miningLevel() < StaminaLevel then
        return false
    end
    local stamina = API.LocalPlayer_HoverProgress()
    return stamina > 0 and stamina <= LowStamina
end

local function applyLocation(index)
    local location = Locations[index]
    State.Location = index
    Config.Rock = location.Rock
    Config.RockSpot = Movement.copyTile(location.RockSpot)
    Config.Bank = Movement.copyTile(location.Bank)
end

local function bestLocationForLevel(level)
    local best = 1
    for i, location in ipairs(Locations) do
        if findRock(location.Rock).Level <= level then
            best = i
        end
    end
    return best
end

-- In "By level" mode the location follows the player's level, so a level-up
-- sends the script to the next rock the next time it goes to mine.
local function followLevel()
    if not Config.ByLevel then
        return
    end

    local best = bestLocationForLevel(miningLevel())
    if best ~= State.Location or Config.Rock ~= Locations[best].Rock then
        applyLocation(best)
    end
end

local function drawRockMode()
    local changed, index = ImGui.Combo("Rock mode", Config.ByLevel and 1 or 0, RockModes)
    if changed then
        Config.ByLevel = index == 1
    end

    if Config.ByLevel then
        ImGui.Text("Level " .. miningLevel() .. ": " .. Locations[State.Location].Name)
        return
    end

    local locationChanged, location = ImGui.Combo("Location", State.Location - 1, LocationNames)
    if locationChanged then
        applyLocation(location + 1)
    end
end

local function drawRocks()
    ImGui.SeparatorText("Rocks")
    drawRockMode()
    if Config.ByLevel then
        return
    end

    Gui.tile("Rock spot", Config.RockSpot)
    local changed, index = ImGui.Combo("Rock", Gui.indexOf(RockNames, Config.Rock), RockNames)
    if changed then
        Config.Rock = RockNames[index + 1]
    end
end

local function drawMode()
    ImGui.SeparatorText("When inventory is full")
    local changed, index = ImGui.Combo("Mode", Config.PowerMine and 1 or 0, Modes)
    if changed then
        Config.PowerMine = index == 1
    end
    Config.UseOreBox = Gui.checkbox("Fill ore box", Config.UseOreBox)
    Config.UseRockertunities = Gui.checkbox("Use rockertunities", Config.UseRockertunities)
end

local function drawBank()
    if Config.PowerMine then
        return
    end

    ImGui.SeparatorText("Bank")
    Config.BankType = Gui.combo("Bank type", Config.BankType, Banking.TypeNames)
    if not Config.ByLevel then
        Gui.tile("Bank", Config.Bank)
    end
end

applyLocation(1)

Gui.show("Miner", function()
    drawRocks()
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

    if API.ReadPlayerMovin2() then
        API.RandomSleep2(50, 100, 100)
        goto continue
    end

    if Inventory:IsFull() then
        if not Config.PowerMine and fillOreBox() then
            State.Status = "Filling ore box"
            goto continue
        end

        if Config.PowerMine then
            State.Status = "Dropping ore"
            if Items.dropAll(isOre) then
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

    if API.CheckAnim(10) then
        if mineRockertunity() then
            State.Status = "Mining rockertunity"
        elseif isStaminaLow() then
            State.Status = "Refreshing stamina"
            mine()
        end
        goto continue
    end

    followLevel()

    if not Movement.isNear(Config.RockSpot, Config.AreaRadius) then
        State.Status = "Walking to rocks"
        Movement.moveTo(Config.RockSpot)
        goto continue
    end

    State.Status = "Mining " .. Config.Rock
    mine()

    ::continue::
    API.RandomSleep2(100, 200, 200)
end
