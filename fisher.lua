local API = require("api")
local Slib = require("slib")
API.SetDrawTrackedSkills(true)

while API.Read_LoopyLoop() do

    if API.CheckAnim(10) or API.isProcessing() or API.ReadPlayerMovin2() then
        API.RandomSleep2(50, 100, 100)
        goto continue
    end

    if Inventory:IsFull() then
        if Slib:IsPlayerInArea(2899,3471,0,20) then 
            Slib:MoveTo(2889,3533,0)
            goto continue
        end

        Interact:Object("Bank chest","Load Last Preset from")
        goto continue
    end

    if Slib:IsPlayerInArea(2889,3533,0,20) then 
        Slib:MoveTo(2899,3471,0)
        goto continue
    end

    if Slib:IsPlayerInArea(2899,3471,0,20) then 
        Interact:NPC("Fishing spot", "Cage")
        goto continue
    end

    ::continue::
    API.RandomSleep2(100, 200, 200)
end