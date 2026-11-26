local API = require("api")
local Banking = require("utils.banking")
local Gui = require("utils.gui")
local Items = require("utils.items")
local Movement = require("utils.movement")
local Objects = require("utils.objects")
local Player = require("utils.player")
local Slib = require("slib")
local Stamina = require("utils.stamina")
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
    Entrance = nil,
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
        Name = "Varrock SW iron",
        Rock = "Iron rock",
        RockSpot = { x = 3181, y = 3372, z = 0 },
        Bank = { x = 3187, y = 3440, z = 0 },
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
    -- Combinations mine both ores of a bar at one mine. Every bar here takes one
    -- of each ore (RS3 Wiki), and adamant uses luminite, not coal, since 2019.
    {
        Name = "Bronze: Lumbridge SE copper + tin",
        Combo = {
            { Rock = "Copper rock", RockSpot = { x = 3229, y = 3148, z = 0 } },
            { Rock = "Tin rock", RockSpot = { x = 3225, y = 3146, z = 0 } },
        },
        Bank = { x = 3270, y = 3168, z = 0 },
    },
    {
        Name = "Steel: Lumbridge SW iron + coal",
        Combo = {
            { Rock = "Iron rock", RockSpot = { x = 3143, y = 3147, z = 0 } },
            { Rock = "Coal rock", RockSpot = { x = 3145, y = 3144, z = 0 } },
        },
        Bank = { x = 3093, y = 3244, z = 0 },
    },
    {
        Name = "Mithril: Legends' Guild mithril + coal",
        Combo = {
            { Rock = "Mithril rock", RockSpot = { x = 2690, y = 3333, z = 0 } },
            { Rock = "Coal rock", RockSpot = { x = 2710, y = 3333, z = 0 } },
        },
        Bank = { x = 2653, y = 3284, z = 0 },
    },
    {
        Name = "Adamant: Anachronia adamantite + luminite",
        Combo = {
            { Rock = "Adamantite rock", RockSpot = { x = 3795, y = 4308, z = 0 } },
            { Rock = "Luminite rock", RockSpot = { x = 3799, y = 4311, z = 0 } },
        },
        Bank = { x = 3929, y = 4263, z = 0 },
    },
    -- Free-to-play luminite is only in the Dwarven mines under Falador, so these
    -- combinations climb down an entrance and each ore banks at its nearest bank.
    -- Runite needs 60 Mining for the Mining Guild.
    {
        Name = "Rune (F2P): Mining Guild runite + Dwarven luminite",
        Combo = {
            {
                Rock = "Runite rock",
                RockSpot = { x = 3030, y = 9733, z = 0 },
                Bank = { x = 3015, y = 3357, z = 0 },
                Entrance = { Tile = { x = 3020, y = 3339, z = 0 }, Object = "Ladder" },
            },
            {
                Rock = "Luminite rock",
                RockSpot = { x = 3036, y = 9764, z = 0 },
                Bank = { x = 3015, y = 3357, z = 0 },
                Entrance = { Tile = { x = 3060, y = 3378, z = 0 }, Object = "Staircase" },
            },
        },
    },
    {
        Name = "Adamant (F2P): Varrock SE adamantite + Dwarven luminite",
        Combo = {
            {
                Rock = "Adamantite rock",
                RockSpot = { x = 3291, y = 3361, z = 0 },
                Bank = { x = 3254, y = 3421, z = 0 },
            },
            {
                Rock = "Luminite rock",
                RockSpot = { x = 3036, y = 9764, z = 0 },
                Bank = { x = 3015, y = 3357, z = 0 },
                Entrance = { Tile = { x = 3060, y = 3378, z = 0 }, Object = "Staircase" },
            },
        },
    },
}

-- Rockertunity highlight ids come from community mining scripts.
local RockertunityIds = { 7164, 7165 }
local HighlightType = 4
local ObjectType = 0
local RockertunityRange = 2
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
    Combo = nil,
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

-- A part can bring its own bank and entrance when its ore is mined somewhere
-- else than the other ore of the combination.
local function useComboRock(part)
    Config.Rock = part.Rock
    Config.RockSpot = Movement.copyTile(part.RockSpot)
    Config.Entrance = part.Entrance
    if part.Bank ~= nil then
        Config.Bank = Movement.copyTile(part.Bank)
    end
end

local function bankedAmount(oreName)
    local item = Banking.findItem(function(candidate)
        return candidate.name == oreName
    end)
    return item and item.amount or 0
end

-- Each trip mines one ore of the combination until the inventory is full, and
-- picks the one the bank has fewer of, so the two even out over the trips.
local function chooseComboRock()
    if State.Combo == nil then
        return
    end

    API.RandomSleep2(600, 200, 200)
    local fewest, fewestAmount = nil, math.huge
    for _, part in ipairs(State.Combo) do
        local amount = bankedAmount(findRock(part.Rock).Ore)
        if amount < fewestAmount then
            fewest, fewestAmount = part, amount
        end
    end
    useComboRock(fewest)
end

-- A rockertunity highlights one rock near the one being mined. Clicking that
-- rock gives one much stronger hit. The highlight is a nameless object of its
-- own, so the click goes to the rock under it, on the rock's own tile.
local function mineRockertunity()
    if not Config.UseRockertunities then
        return false
    end

    local highlight = (API.GetAllObjArray1(RockertunityIds, 25, { HighlightType }) or {})[1]
    if highlight == nil then
        return false
    end

    local rocks = API.ReadAllObjectsArray({ ObjectType }, { -1 }, {}) or {}
    local rock = Objects.nearestTo(rocks, highlight.Tile_XYZ, RockertunityRange, function(object)
        return object.Name == Config.Rock
    end)
    if rock == nil then
        Slib:Warn(("[Miner] No %s under the rockertunity at %.0f, %.0f"):format(
            Config.Rock, highlight.Tile_XYZ.x, highlight.Tile_XYZ.y))
        return false
    end

    Interact:Object(rock.Name, MineAction, rock.Tile_XYZ, 1)
    API.RandomSleep2(1200, 300, 300)
    return true
end

local function mine()
    Interact:Object(Config.Rock, MineAction)
    Player.waitUntilBusy()
end

local function applyLocation(index)
    local location = Locations[index]
    State.Location = index
    State.Combo = location.Combo
    Config.Entrance = nil
    if location.Bank ~= nil then
        Config.Bank = Movement.copyTile(location.Bank)
    end
    if location.Combo ~= nil then
        useComboRock(location.Combo[1])
        return
    end
    Config.Rock = location.Rock
    Config.RockSpot = Movement.copyTile(location.RockSpot)
end

-- Combinations are picked by hand, so "By level" only considers single rocks.
local function bestLocationForLevel(level)
    local best = 1
    for i, location in ipairs(Locations) do
        if location.Combo == nil and findRock(location.Rock).Level <= level then
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

    if State.Combo ~= nil then
        ImGui.Text("This trip: " .. Config.Rock .. " until the inventory is full")
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
    ImGui.Text(("Stamina: %.0f (max seen %.0f, refills at %.0f%%)"):format(Stamina.Last, Stamina.Max, Stamina.Share * 100))
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
    Gui.update()

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

        if not Movement.goTo(Config.Bank, Config.AreaRadius, Config.Entrance) then
            State.Status = "Walking to bank"
            goto continue
        end

        State.Status = "Banking"
        if Bank:IsOpen() then
            depositAtBank()
            chooseComboRock()
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
        elseif Stamina.isLow(miningLevel()) then
            State.Status = "Refreshing stamina"
            Interact:Object(Config.Rock, MineAction)
            API.RandomSleep2(1200, 300, 300)
        end
        goto continue
    end

    followLevel()

    if not Movement.goTo(Config.RockSpot, Config.AreaRadius, Config.Entrance) then
        State.Status = "Walking to rocks"
        goto continue
    end

    State.Status = "Mining " .. Config.Rock
    mine()

    ::continue::
    API.RandomSleep2(100, 200, 200)
end
