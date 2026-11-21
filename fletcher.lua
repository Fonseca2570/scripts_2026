local API = require("api")
local Banking = require("utils.banking")
local Gui = require("utils.gui")
local Items = require("utils.items")
local Production = require("utils.production")
API.SetDrawTrackedSkills(true)

local Config = {
    BankType = "Auto",
    ToolKey = 1,
}

-- Logs and the Fletching level to cut them into shafts, from the RS3 Wiki,
-- highest first. Arrow shafts were renamed to "Shaft" in July 2026.
local Logs = {
    { Name = "Elder logs", Level = 90 },
    { Name = "Magic logs", Level = 80 },
    { Name = "Yew logs", Level = 70 },
    { Name = "Mahogany logs", Level = 60 },
    { Name = "Acadia logs", Level = 50 },
    { Name = "Maple logs", Level = 40 },
    { Name = "Teak logs", Level = 30 },
    { Name = "Willow logs", Level = 20 },
    { Name = "Oak logs", Level = 10 },
    { Name = "Logs", Level = 1 },
}

-- "Craft" is the first option on logs and uses the tool belt's knife.
local CraftOption = 1

-- The first time logs are crafted the game asks which tool to use (knife,
-- tinderbox, add to bonfire) before the Make-X window. Its options answer to
-- the number keys 1-3, but no source says which one is the knife, so the key
-- is a setting.
local NumberKeys = { 0x31, 0x32, 0x33 }

local LogLevels = {}
for _, log in ipairs(Logs) do
    LogLevels[log.Name:lower()] = log.Level
end

local State = {
    Running = false,
    Status = "Paused",
    Log = "",
}

local function fletchingLevel()
    return API.XPLevelTable(API.GetSkillXP("FLETCHING"))
end

local function isFletchable(item)
    local level = LogLevels[Items.lowerName(item)]
    return level ~= nil and level <= fletchingLevel()
end

-- Make-X remembers the last product, so a bow or stock in the inventory means
-- it was picked last time and the player has to pick Shaft once.
local function isOtherProduct(item)
    local name = Items.lowerName(item)
    return name:find("bow", 1, true) ~= nil or name:find("stock", 1, true) ~= nil
end

-- Returns the status to show.
local function fletch(log)
    if Production.isMakeXOpen() then
        Production.confirm()
        return "Fletching " .. log.name
    end

    if API.Check_Dialog_Open() then
        API.KeyboardPress2(NumberKeys[Config.ToolKey], 60, 100)
        return "Choosing the knife"
    end

    API.DoAction_Inventory1(log.id, 0, CraftOption, API.OFF_ACT_GeneralInterface_route)
    return "Fletching " .. log.name
end

local function bestLogInBank()
    local level = fletchingLevel()
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
        if Items.find(isFletchable) ~= nil then
            break
        end
    end
    Banking.close()
    return true
end

local function stop(status)
    State.Running = false
    State.Status = status
    API.Write_LoopyLoop(false)
end

local function drawFletching()
    ImGui.SeparatorText("Fletching")
    ImGui.Text("Fletching level: " .. fletchingLevel())
    ImGui.Text("Logs: " .. (State.Log ~= "" and State.Log or "-"))
    ImGui.Text("Makes shafts. Pick Shaft in the fletching window once if it")
    ImGui.Text("remembers another item.")

    local changed, key = ImGui.InputInt("Knife key (tool choice)", Config.ToolKey, 1, 1)
    if changed then
        Config.ToolKey = math.min(#NumberKeys, math.max(1, key))
    end
end

local function drawBank()
    ImGui.SeparatorText("Bank")
    Config.BankType = Gui.combo("Bank type", Config.BankType, Banking.TypeNames)
end

Gui.show("Fletcher", function()
    drawFletching()
    drawBank()
    Gui.controls(Config, State)
end)

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

    if Items.find(isOtherProduct) ~= nil then
        stop("Not making shafts: pick Shaft in the fletching window")
        goto continue
    end

    do
        local log = Items.find(isFletchable)
        if log ~= nil then
            State.Log = log.name
            State.Status = fletch(log)
            goto continue
        end
    end

    if Bank:IsOpen() then
        State.Status = "Banking"
        if not withdrawLogs() then
            stop("Nothing left to fletch")
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
