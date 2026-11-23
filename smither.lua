local API = require("api")
local Gui = require("utils.gui")
local Items = require("utils.items")
local Player = require("utils.player")
API.SetDrawTrackedSkills(true)

local Config = {
    ReheatBelow = 0,
}

local AnvilName = "Anvil"
local SmithAction = "Smith"
local OpenAction = "Open smithing interface"
local ForgeName = "Forge"
local HeatAction = "Heat"
local UnfinishedName = "unfinished smithing item"

-- Smithing interface ids from community smithing scripts, not from the API
-- docs. They are the same window the smelter uses: interface 37, Begin Project
-- is component 163.
local SmithingStatus = 85
local SmithingInterface = 37
local BeginButton = 163

local State = {
    Running = false,
    Status = "Paused",
}

local function level(skill)
    return API.XPLevelTable(API.GetSkillXP(skill))
end

-- High heat, where each strike makes double progress, starts at two thirds of
-- the unbonused maximum heat (RS3 Wiki). Material bonuses raise the maximum but
-- not this threshold.
local function highHeat()
    return math.floor((300 + 3 * level("SMITHING") + 3 * level("FIREMAKING")) * 2 / 3)
end

local function reheatBelow()
    if Config.ReheatBelow > 0 then
        return Config.ReheatBelow
    end
    return highHeat()
end

local function heat()
    return API.LocalPlayer_HoverProgress()
end

local function isUnfinished(item)
    return Items.lowerName(item) == UnfinishedName
end

local function isSmithingOpen()
    return API.Compare2874Status(SmithingStatus, false)
end

-- The heat bar is only shown while smithing, so it is only read then.
local function isHeatLow()
    local current = heat()
    return current > 0 and current < reheatBelow()
end

-- Heat only goes into the first unfinished item, and the forge needs a few
-- ticks, so wait for the heating to finish instead of clicking again.
local function reheat()
    Interact:Object(ForgeName, HeatAction)
    Player.waitUntilBusy()
    Player.waitUntilIdle()
end

local function continueSmithing()
    Interact:Object(AnvilName, SmithAction)
    Player.waitUntilBusy()
end

local function openSmithingWindow()
    Interact:Object(AnvilName, OpenAction)
    for _ = 1, 20 do
        API.RandomSleep2(150, 50, 50)
        if isSmithingOpen() then
            return
        end
    end
end

-- The smithing window is expected to remember the last item picked, so Begin
-- Project starts another one of it. Returns false when no item was made, for
-- example when the bars ran out or no item was ever picked.
local function beginNewItem()
    API.DoAction_Interface(0x24, 0xffffffff, 1, SmithingInterface, BeginButton, -1, API.OFF_ACT_GeneralInterface_route)
    for _ = 1, 20 do
        API.RandomSleep2(150, 50, 50)
        if Items.find(isUnfinished) ~= nil then
            return true
        end
    end
    return false
end

local function stop(status)
    State.Running = false
    State.Status = status
    API.Write_LoopyLoop(false)
end

local function drawSmithing()
    ImGui.SeparatorText("Smithing")
    ImGui.Text("Smithing level: " .. level("SMITHING"))
    ImGui.Text("Heat now: " .. heat() .. "  (high heat from " .. highHeat() .. ")")

    local changed, value = ImGui.InputInt("Reheat below (0 = high heat)", Config.ReheatBelow, 10, 50)
    if changed then
        Config.ReheatBelow = math.max(0, value)
    end
    ImGui.Text("Pick the item in the smithing window once; new")
    ImGui.Text("items repeat the last one.")
end

Gui.show("Smither", function()
    drawSmithing()
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

    if Items.find(isUnfinished) ~= nil then
        if isHeatLow() then
            State.Status = "Heating"
            reheat()
            goto continue
        end

        if API.CheckAnim(10) then
            State.Status = "Smithing"
            goto continue
        end

        State.Status = "Continuing unfinished item"
        continueSmithing()
        goto continue
    end

    if API.CheckAnim(10) or API.isProcessing() then
        goto continue
    end

    if isSmithingOpen() then
        State.Status = "Starting a new item"
        if not beginNewItem() then
            stop("No item started: pick one in the smithing window or add bars")
        end
        goto continue
    end

    State.Status = "Opening smithing window"
    openSmithingWindow()

    ::continue::
    API.RandomSleep2(100, 200, 200)
end
