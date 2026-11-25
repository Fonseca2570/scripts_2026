local API = require("api")
local Gui = require("utils.gui")
local Items = require("utils.items")
local Player = require("utils.player")
local Production = require("utils.production")
API.SetDrawTrackedSkills(true)

-- Burthorpe mine only has common gem rocks (RS3 Wiki). Start the script
-- inside the mine; it mines the nearest rock and never walks.
local RockName = "Common gem rock"
local MineAction = "Mine"

-- Common gem rock gems and the Crafting level to cut them, from the RS3 Wiki.
-- Opal, jade and red topaz can fail into a crushed gem.
local Gems = {
    { Uncut = "Uncut lapis lazuli", Cut = "Lapis lazuli", Level = 1 },
    { Uncut = "Uncut opal", Cut = "Opal", Level = 1 },
    { Uncut = "Uncut jade", Cut = "Jade", Level = 13 },
    { Uncut = "Uncut red topaz", Cut = "Red topaz", Level = 16 },
}
local CrushedGem = "crushed gem"

-- "Craft" is the first option on uncut gems and uses the tool belt's chisel.
local CraftOption = 1

local CutLevels, GemNames = {}, { [CrushedGem] = true }
for _, gem in ipairs(Gems) do
    CutLevels[gem.Uncut:lower()] = gem.Level
    GemNames[gem.Uncut:lower()] = true
    GemNames[gem.Cut:lower()] = true
end

local State = {
    Running = false,
    Status = "Paused",
}

local function level(skill)
    return API.XPLevelTable(API.GetSkillXP(skill))
end

local function isCuttable(item)
    local cutLevel = CutLevels[Items.lowerName(item)]
    return cutLevel ~= nil and cutLevel <= level("CRAFTING")
end

local function isGem(item)
    return GemNames[Items.lowerName(item)] ~= nil
end

local function cut(gem)
    if Production.isMakeXOpen() then
        Production.confirm()
    else
        API.DoAction_Inventory1(gem.id, 0, CraftOption, API.OFF_ACT_GeneralInterface_route)
    end
    Player.waitUntilBusy()
end

local function mine()
    Interact:Object(RockName, MineAction)
    Player.waitUntilBusy()
end

local function stop(status)
    State.Running = false
    State.Status = status
    API.Write_LoopyLoop(false)
end

Gui.show("Gem Miner", function()
    ImGui.SeparatorText("Gems")
    ImGui.Text("Mining level: " .. level("MINING") .. "   Crafting level: " .. level("CRAFTING"))
    ImGui.Text("Start inside Burthorpe mine. Mines " .. RockName:lower() .. "s,")
    ImGui.Text("cuts what your Crafting level allows and drops")
    ImGui.Text("every gem.")
    Gui.controls({}, State)
end)

API.Write_LoopyLoop(true)

while API.Read_LoopyLoop() do

    if not State.Running then
        API.RandomSleep2(200, 100, 100)
        goto continue
    end

    if API.ReadPlayerMovin2() or API.isProcessing() or API.CheckAnim(10) then
        API.RandomSleep2(50, 100, 100)
        goto continue
    end

    if Inventory:IsFull() then
        local gem = Items.find(isCuttable)
        if gem ~= nil then
            State.Status = "Cutting " .. gem.name:lower()
            cut(gem)
            goto continue
        end

        State.Status = "Dropping gems"
        if not Items.dropAll(isGem) then
            stop("Backpack is full of other items")
        end
        goto continue
    end

    State.Status = "Mining"
    mine()

    ::continue::
    API.RandomSleep2(100, 200, 200)
end
