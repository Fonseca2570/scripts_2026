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

-- Common gem rock gems, the Crafting level to cut them and the Fletching level
-- to make 12 stackable bolt tips from the cut gem, from the RS3 Wiki. Lapis
-- lazuli has no bolt tips. Opal, jade and red topaz can fail into a crushed gem.
local Gems = {
    { Uncut = "Uncut lapis lazuli", Cut = "Lapis lazuli gem", CutLevel = 1 },
    { Uncut = "Uncut opal", Cut = "Opal", CutLevel = 1, TipsLevel = 11 },
    { Uncut = "Uncut jade", Cut = "Jade", CutLevel = 13, TipsLevel = 26 },
    { Uncut = "Uncut red topaz", Cut = "Red topaz", CutLevel = 16, TipsLevel = 48 },
}
local CrushedGem = "crushed gem"

-- "Craft" is the first option on uncut and cut gems and uses the tool belt's
-- chisel: uncut gems are cut, cut gems are made into bolt tips.
local CraftOption = 1

-- Levels to craft each item, keyed by lower-case name. Bolt tips are not gems,
-- so they are never dropped.
local Crafts, GemNames = {}, { [CrushedGem] = true }
for _, gem in ipairs(Gems) do
    Crafts[gem.Uncut:lower()] = { Skill = "CRAFTING", Level = gem.CutLevel }
    if gem.TipsLevel ~= nil then
        Crafts[gem.Cut:lower()] = { Skill = "FLETCHING", Level = gem.TipsLevel }
    end
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

local function isCraftable(item)
    local craft = Crafts[Items.lowerName(item)]
    return craft ~= nil and craft.Level <= level(craft.Skill)
end

local function isGem(item)
    return GemNames[Items.lowerName(item)] ~= nil
end

local function craft(gem)
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
    ImGui.Text(("Mining %d   Crafting %d   Fletching %d"):format(level("MINING"), level("CRAFTING"), level("FLETCHING")))
    ImGui.Text("Start inside Burthorpe mine. Mines " .. RockName:lower() .. "s,")
    ImGui.Text("cuts the gems, makes bolt tips and drops the")
    ImGui.Text("gems that can't be cut or made into tips.")
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
        local gem = Items.find(isCraftable)
        if gem ~= nil then
            State.Status = "Crafting " .. gem.name:lower()
            craft(gem)
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
