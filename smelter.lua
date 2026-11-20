local API = require("api")
local Gui = require("utils.gui")
local Items = require("utils.items")
API.SetDrawTrackedSkills(true)

local Config = {
    FurnaceName = "Furnace",
    SmeltAction = "Smelt",
    DepositAction = "Deposit-all (into metal bank)",
}

-- Bars smelted from ores in the furnace's metal bank, highest level first. Item
-- ids and levels from the RS3 Wiki. Primal and platinum bars are left out.
local Bars = {
    { Name = "Elder rune bar", Id = 44844, Level = 90 },
    { Name = "Bane bar", Id = 44842, Level = 80 },
    { Name = "Necronium bar", Id = 44840, Level = 70 },
    { Name = "Orikalkum bar", Id = 44838, Level = 60 },
    { Name = "Rune bar", Id = 2363, Level = 50 },
    { Name = "Adamant bar", Id = 2361, Level = 40 },
    { Name = "Gold bar", Id = 2357, Level = 40 },
    { Name = "Mithril bar", Id = 2359, Level = 30 },
    { Name = "Steel bar", Id = 2353, Level = 20 },
    { Name = "Silver bar", Id = 2355, Level = 20 },
    { Name = "Iron bar", Id = 2351, Level = 10 },
    { Name = "Bronze bar", Id = 2349, Level = 1 },
}

-- Smelting interface ids from community smelting scripts, not from the API docs.
-- The bar list is interface 37 component 103, one child per bar.
local SmithingStatus = 85
local SmithingInterface = 37
local BarList = 103
local BeginButton = 163
local BarListSize = 40
local SelectedBarVar = 8333
local QuantityVar = 8336
local SmeltingQueueVar = 2228

local State = {
    Running = false,
    Status = "Paused",
    Bar = "",
    BarSlots = nil,
}

local function smithingLevel()
    return API.XPLevelTable(API.GetSkillXP("SMITHING"))
end

local function var(id)
    return API.VB_FindPSettinOrder(id).state
end

local function isSmithingOpen()
    return API.Compare2874Status(SmithingStatus, false)
end

local function isSmelting()
    return var(SmeltingQueueVar) > 0
end

local function isBar(item)
    return Items.lowerName(item):find(" bar$") ~= nil
end

local function clickInterface(component, child)
    API.DoAction_Interface(0x24, 0xffffffff, 1, SmithingInterface, component, child, API.OFF_ACT_GeneralInterface_route)
end

-- The bar order in the list is not documented, so click every child once and
-- read which bar each one selects.
local function mapBarSlots()
    local slots = {}
    for child = 0, BarListSize do
        clickInterface(BarList, child)
        API.RandomSleep2(250, 50, 50)
        local selected = var(SelectedBarVar)
        if selected > 0 and slots[selected] == nil then
            slots[selected] = child
        end
    end
    return slots
end

local function selectBar(bar)
    if var(SelectedBarVar) == bar.Id then
        return true
    end

    State.BarSlots = State.BarSlots or mapBarSlots()
    local child = State.BarSlots[bar.Id]
    if child == nil then
        return false
    end

    clickInterface(BarList, child)
    for _ = 1, 10 do
        API.RandomSleep2(100, 50, 50)
        if var(SelectedBarVar) == bar.Id then
            return true
        end
    end
    return false
end

-- The quantity shown for the selected bar is 0 when the metal bank lacks its
-- ores, so try bars from the best one the player's level allows downwards.
local function chooseBar()
    local level = smithingLevel()
    for _, bar in ipairs(Bars) do
        if bar.Level <= level and selectBar(bar) then
            API.RandomSleep2(200, 50, 50)
            if var(QuantityVar) > 0 then
                return bar
            end
        end
    end
    return nil
end

local function smelt()
    local bar = chooseBar()
    if bar == nil then
        return false
    end

    State.Bar = bar.Name
    clickInterface(BeginButton, -1)
    return true
end

local function drawSmelting()
    ImGui.SeparatorText("Smelting")
    ImGui.Text("Smithing level: " .. smithingLevel())
    ImGui.Text("Bar: " .. (State.Bar ~= "" and State.Bar or "-"))
    Config.FurnaceName = Gui.text("Furnace", Config.FurnaceName)
    Config.DepositAction = Gui.text("Deposit action", Config.DepositAction)
end

Gui.show("Smelter", function()
    drawSmelting()
    Gui.controls(Config, State)
end)

API.Write_LoopyLoop(true)

while API.Read_LoopyLoop() do

    if not State.Running then
        API.RandomSleep2(200, 100, 100)
        goto continue
    end

    if isSmelting() or API.CheckAnim(10) or API.isProcessing() or API.ReadPlayerMovin2() then
        API.RandomSleep2(50, 100, 100)
        goto continue
    end

    if Items.find(isBar) ~= nil then
        State.Status = "Depositing bars"
        Interact:Object(Config.FurnaceName, Config.DepositAction)
        goto continue
    end

    if isSmithingOpen() then
        State.Status = "Choosing bar"
        if not smelt() then
            State.Running = false
            State.Status = "Nothing left to smelt"
            API.Write_LoopyLoop(false)
            goto continue
        end
        State.Status = "Smelting " .. State.Bar
        goto continue
    end

    State.Status = "Opening furnace"
    Interact:Object(Config.FurnaceName, Config.SmeltAction)

    ::continue::
    API.RandomSleep2(100, 200, 200)
end
