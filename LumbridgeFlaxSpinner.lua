--[[

@title Lumbridge Castle Flax Spinner
@description Spins flax into bowstrings
@author Higgins <discord@higginshax>
@date 22/07/2023
@version 1.1

Flax Bank Preset 1
Start at top of Lumbridge Castle bank

Crafting XP Per Hour ~ 20,000
Bowstrings Per Hour ~ 1,200

On screen paint progress report and final progress report output to console window

--]]

local API = require("api")
local startTime = os.time()
local startXp = API.GetSkillXP("CRAFTING")
local strings, fail = 0, 0
API.SetDrawTrackedSkills(true)

ID = {
    FLAX = 1779,
    BOWSTRING = 1777,
    SPINNING_WHEEL = 36970,
    STAIRS_DOWN = 36775,
    STAIRS_UP = 36774,
    BANK_BOOTH = 36786
}

local function isCrafterOpen()
    return #API.ScanForInterfaceTest2Get2(true, { 1371, 21, -1, 15 }) > 0
end

local function spin()
    if isCrafterOpen() then
        API.KeyboardPress2(0x20, 60, 100)
        API.RandomSleep2(300, 600, 800)
    else
        Interact:Object("Spinning wheel","Spin")
        API.RandomSleep2(300, 400, 500)
    end
end

local function stairsUp()
    Interact:Object("Staircase","Climb-up")
    API.RandomSleep2(600, 400, 500)
end

local function stairsDown()
    Interact:Object("Staircase","Climb-down")
    API.RandomSleep2(800, 400, 500)
end

local function bank()
    if API.BankOpen2() then
        strings = strings + Inventory:GetItemAmount(ID.BOWSTRING)
        API.KeyboardPress2(0x31, 60, 100)
        API.RandomSleep2(300, 400, 400)
    else
        Interact:Object("Bank booth","Load Last Preset from")
        API.RandomSleep2(300, 600, 800)
    end
end

while API.Read_LoopyLoop() do

    if API.CheckAnim(10) or API.isProcessing() or API.ReadPlayerMovin2() then
        API.RandomSleep2(50, 100, 100)
        goto continue
    end

    if Inventory:GetItemAmount(ID.BOWSTRING) > 0 or Inventory:GetItemAmount(ID.FLAX) < 1 then
        if API.GetFloorLv_2() == 2 then
            bank()
            if Inventory:GetItemAmount(ID.FLAX) < 1 then
                fail = fail + 1
            end
            if fail > 2 then
                API.Write_LoopyLoop(0)
                break
            end
        else
            stairsUp()
        end
    elseif Inventory:GetItemAmount(ID.FLAX) > 0 then
        fail = 0
        if API.GetFloorLv_2() == 2 then
            stairsDown()
        else    
            spin()
        end
    end

    if API.GetFloorLv_2() == 0 then 
        stairsUp()
    end

    ::continue::
    API.RandomSleep2(100, 200, 200)
end