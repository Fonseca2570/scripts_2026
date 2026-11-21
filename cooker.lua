local API = require("api")
local Banking = require("utils.banking")
local Gui = require("utils.gui")
local Items = require("utils.items")
local Objects = require("utils.objects")
local Production = require("utils.production")
API.SetDrawTrackedSkills(true)

local Config = {
    BankType = "Auto",
    StationAction = "",
}

-- Raw food cooked directly on a range or fire, with the Cooking level from the
-- RS3 Wiki. Raw items that are not here are never withdrawn: potatoes burn on
-- fires, spit meats and oomlies need preparing first, and tarpon, sillago and
-- wobbegong make oil instead of food. Karambwan is cooked as food from 30.
local RawFoods = {
    ["raw minnow"] = 1,
    ["raw crayfish"] = 1,
    ["raw shrimps"] = 1,
    ["raw karambwanji"] = 1,
    ["raw sardine"] = 1,
    ["raw anchovies"] = 1,
    ["raw beef"] = 1,
    ["raw bear meat"] = 1,
    ["raw wolf meat"] = 1,
    ["raw yak meat"] = 1,
    ["raw rat meat"] = 1,
    ["raw chicken"] = 1,
    ["raw herring"] = 5,
    ["raw mackerel"] = 10,
    ["raw bacon"] = 14,
    ["raw trout"] = 15,
    ["raw cod"] = 18,
    ["raw pike"] = 20,
    ["raw bacon stack"] = 24,
    ["raw salmon"] = 25,
    ["raw slimy eel"] = 28,
    ["raw tuna"] = 30,
    ["raw karambwan"] = 30,
    ["raw bacon pile"] = 34,
    ["raw rainbow fish"] = 35,
    ["raw cave eel"] = 38,
    ["raw lobster"] = 40,
    ["raw bass"] = 43,
    ["raw bacon heap"] = 44,
    ["raw swordfish"] = 45,
    ["raw desert sole"] = 52,
    ["raw lava eel"] = 53,
    ["raw bacon mound"] = 54,
    ["raw catfish"] = 60,
    ["raw monkfish"] = 62,
    ["raw ghostly sole"] = 66,
    ["raw beltfish"] = 72,
    ["raw arcane apoterrasaur meat"] = 75,
    ["raw bagrada rex meat"] = 75,
    ["raw shark"] = 80,
    ["raw asciatops meat"] = 81,
    ["raw sea turtle"] = 82,
    ["raw great white shark"] = 84,
    ["raw giant crayfish"] = 86,
    ["raw cavefish"] = 88,
    ["raw manta ray"] = 91,
    ["raw rocktail"] = 93,
}

-- Range and fire object names from the RS3 Wiki. A bonfire is a "Fire" with
-- logs added, so both are matched.
local Stations = {
    ["range"] = true,
    ["cooking range"] = true,
    ["clay oven"] = true,
    ["grill"] = true,
    ["fire"] = true,
    ["bonfire"] = true,
    ["fire pit"] = true,
}

local State = {
    Running = false,
    Status = "Paused",
    Food = "",
}

local function cookingLevel()
    return API.XPLevelTable(API.GetSkillXP("COOKING"))
end

local function isCookable(item)
    local level = RawFoods[Items.lowerName(item)]
    return level ~= nil and level <= cookingLevel()
end

local function findStation()
    local objects = API.ReadAllObjectsArray({ 0, 12 }, { -1 }, {}) or {}
    return Objects.nearest(objects, function(object)
        return Stations[(object.Name or ""):lower()] == true
    end)
end

-- The Make-X interface opens on the station's default action (Cook-at on
-- ranges, Use on fires) and Space confirms it.
local function cook()
    if Production.isMakeXOpen() then
        Production.confirm()
        return true
    end

    local station = findStation()
    if station == nil then
        return false
    end
    local action = Config.StationAction ~= "" and Config.StationAction or station.Action
    Interact:Object(station.Name, action)
    return true
end

local function withdrawFood()
    Bank:DepositInventory()
    API.RandomSleep2(300, 100, 100)

    local food = Banking.findItem(isCookable)
    if food == nil then
        return false
    end

    Bank:WithdrawAll(food.id)
    for _ = 1, 10 do
        API.RandomSleep2(100, 50, 50)
        if Items.find(isCookable) ~= nil then
            break
        end
    end
    Banking.close()
    return true
end

local function drawCooking()
    ImGui.SeparatorText("Cooking")
    ImGui.Text("Cooking level: " .. cookingLevel())
    ImGui.Text("Food: " .. (State.Food ~= "" and State.Food or "-"))
    Config.StationAction = Gui.text("Station action", Config.StationAction)
    ImGui.Text("Leave empty to use the range or fire's default action.")
end

local function drawBank()
    ImGui.SeparatorText("Bank")
    Config.BankType = Gui.combo("Bank type", Config.BankType, Banking.TypeNames)
end

Gui.show("Cooker", function()
    drawCooking()
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

    do
        local food = Items.find(isCookable)
        if food ~= nil then
            State.Food = food.name
            State.Status = "Cooking " .. food.name
            if not cook() then
                State.Status = "No range or fire found"
            end
            goto continue
        end
    end

    if Bank:IsOpen() then
        State.Status = "Banking"
        if not withdrawFood() then
            State.Running = false
            State.Status = "Nothing left to cook"
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
