local API = require("api")
local Banking = require("utils.banking")
local Gui = require("utils.gui")
local Items = require("utils.items")
local Production = require("utils.production")
API.SetDrawTrackedSkills(true)

local Config = {
    Product = "Shafts",
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

-- Arrowheads on headless shafts make 15 arrows, from the RS3 Wiki after the
-- July 2026 rebalance, highest first.
local Arrows = {
    { Name = "Dragon arrowheads", Level = 60 },
    { Name = "Broad arrowheads", Level = 52 },
    { Name = "Rune arrowheads", Level = 50 },
    { Name = "Adamant arrowheads", Level = 40 },
    { Name = "Mithril arrowheads", Level = 30 },
    { Name = "Steel arrowheads", Level = 20 },
    { Name = "Iron arrowheads", Level = 10 },
    { Name = "Bronze arrowheads", Level = 1 },
}

-- Feathering unfinished bolts makes 10 bolts, from the same rebalance.
local Bolts = {
    { Name = "Rune bolts (unf)", Level = 53 },
    { Name = "Adamant bolts (unf)", Level = 43 },
    { Name = "Mithril bolts (unf)", Level = 33 },
    { Name = "Steel bolts (unf)", Level = 23 },
    { Name = "Iron bolts (unf)", Level = 13 },
    { Name = "Bronze bolts (unf)", Level = 3 },
}

-- "Craft" is the first option on logs and uses the tool belt's knife.
-- "Feather" is the first option on unfinished bolts.
local CraftOption = 1
local FeatherOption = 1

local LogLevels = {}
for _, log in ipairs(Logs) do
    LogLevels[log.Name:lower()] = log.Level
end

local State = {
    Running = false,
    Status = "Paused",
    Material = "",
}

local function fletchingLevel()
    return API.XPLevelTable(API.GetSkillXP("FLETCHING"))
end

local function isFletchable(item)
    local level = LogLevels[Items.lowerName(item)]
    return level ~= nil and level <= fletchingLevel()
end

local function isHeadlessShaft(item)
    return Items.lowerName(item) == "headless shaft"
end

local function isShaft(item)
    local name = Items.lowerName(item)
    return name == "shaft" or name == "arrow shaft"
end

local function isFeather(item)
    return Items.lowerName(item) == "feather"
end

-- Make-X remembers the last product, so a bow or stock in the inventory means
-- it was picked last time and the player has to pick Shaft once.
local function isOtherProduct(item)
    local name = Items.lowerName(item)
    return name:find("bow", 1, true) ~= nil or name:find("stock", 1, true) ~= nil
end

-- Returns the highest tier the level allows that matches, as found by find.
local function bestTier(tiers, find)
    local level = fletchingLevel()
    for _, tier in ipairs(tiers) do
        if tier.Level <= level then
            local found = find(function(item)
                return item.name == tier.Name
            end)
            if found ~= nil then
                return found
            end
        end
    end
    return nil
end

local function bestLogInBank()
    return bestTier(Logs, Banking.findItem)
end

-- Deposits the inventory, withdraws every item in the list and closes the bank.
local function withdraw(items)
    Bank:DepositInventory()
    API.RandomSleep2(300, 100, 100)

    for _, item in ipairs(items) do
        Bank:WithdrawAll(item.id)
    end
    for _ = 1, 10 do
        API.RandomSleep2(100, 50, 50)
        if Inventory:Contains(items[#items].id) then
            break
        end
    end
    Banking.close()
    return true
end

-- Each product knows which inventory item it starts from, how to start making
-- it and what to withdraw from the bank. Make-X confirms both the same way.
local Products = {
    {
        Name = "Shafts",
        material = function()
            return Items.find(isFletchable)
        end,
        start = function(log)
            API.DoAction_Inventory1(log.id, 0, CraftOption, API.OFF_ACT_GeneralInterface_route)
        end,
        withdraw = function()
            local log = bestLogInBank()
            if log == nil then
                return false
            end
            return withdraw({ log })
        end,
        isWrongProduct = function()
            return Items.find(isOtherProduct) ~= nil
        end,
    },
    {
        Name = "Headless arrows",
        material = function()
            local shaft = Items.find(isShaft)
            if shaft == nil or Items.find(isFeather) == nil then
                return nil
            end
            return shaft
        end,
        start = function(shaft)
            Inventory:UseItemOnItem(Items.find(isFeather).id, shaft.id)
        end,
        withdraw = function()
            local shafts = Banking.findItem(isShaft)
            local feathers = Banking.findItem(isFeather)
            if shafts == nil or feathers == nil then
                return false
            end
            return withdraw({ shafts, feathers })
        end,
        isWrongProduct = function()
            return false
        end,
    },
    {
        Name = "Arrows",
        material = function()
            if Items.find(isHeadlessShaft) == nil then
                return nil
            end
            return bestTier(Arrows, Items.find)
        end,
        start = function(arrowheads)
            Inventory:UseItemOnItem(arrowheads.id, Items.find(isHeadlessShaft).id)
        end,
        withdraw = function()
            local shafts = Banking.findItem(isHeadlessShaft)
            local arrowheads = bestTier(Arrows, Banking.findItem)
            if shafts == nil or arrowheads == nil then
                return false
            end
            return withdraw({ shafts, arrowheads })
        end,
        isWrongProduct = function()
            return false
        end,
    },
    {
        Name = "Bolts",
        material = function()
            if Items.find(isFeather) == nil then
                return nil
            end
            return bestTier(Bolts, Items.find)
        end,
        start = function(bolts)
            API.DoAction_Inventory1(bolts.id, 0, FeatherOption, API.OFF_ACT_GeneralInterface_route)
        end,
        withdraw = function()
            local bolts = bestTier(Bolts, Banking.findItem)
            local feathers = Banking.findItem(isFeather)
            if bolts == nil or feathers == nil then
                return false
            end
            return withdraw({ bolts, feathers })
        end,
        isWrongProduct = function()
            return false
        end,
    },
}

local ProductHelp = {
    ["Headless arrows"] = "Uses the shafts and feathers in the bank.",
    Arrows = "Uses headless shafts and the best arrowheads.",
    Bolts = "Uses feathers and the best unfinished bolts.",
}

local ProductNames = {}
for i, product in ipairs(Products) do
    ProductNames[i] = product.Name
end

local function selectedProduct()
    return Products[Gui.indexOf(ProductNames, Config.Product) + 1]
end

-- Returns the status to show.
local function fletch(product, material)
    if Production.isMakeXOpen() then
        Production.confirm()
        return "Making " .. product.Name:lower()
    end

    product.start(material)
    return "Making " .. product.Name:lower()
end

local function stop(status)
    State.Running = false
    State.Status = status
    API.Write_LoopyLoop(false)
end

local function drawFletching()
    ImGui.SeparatorText("Fletching")
    Config.Product = Gui.combo("Product", Config.Product, ProductNames)
    ImGui.Text("Fletching level: " .. fletchingLevel())
    ImGui.Text("Using: " .. (State.Material ~= "" and State.Material or "-"))
    if Config.Product == "Shafts" then
        ImGui.Text("Pick Shaft in the fletching window once if it")
        ImGui.Text("remembers another item.")
        return
    end
    ImGui.Text(ProductHelp[Config.Product])
end

Gui.show("Fletcher", function()
    drawFletching()
    Gui.controls(Config, State)
end)

API.Write_LoopyLoop(true)

while API.Read_LoopyLoop() do

    if not State.Running then
        API.RandomSleep2(200, 100, 100)
        goto continue
    end

    if API.CheckAnim(50) or API.isProcessing() or API.ReadPlayerMovin2() then
        API.RandomSleep2(50, 100, 100)
        goto continue
    end

    do
        local product = selectedProduct()
        if product.isWrongProduct() then
            stop("Not making shafts: pick Shaft in the fletching window")
            goto continue
        end

        local material = product.material()
        if material ~= nil then
            State.Material = material.name
            State.Status = fletch(product, material)
            goto continue
        end

        if Bank:IsOpen() then
            State.Status = "Banking"
            if not product.withdraw() then
                stop("Nothing left to make " .. product.Name:lower())
            end
            goto continue
        end
    end

    State.Status = "Opening bank"
    if not Banking.open("Auto") then
        State.Status = "No bank found"
    end

    ::continue::
    API.RandomSleep2(100, 200, 200)
end
