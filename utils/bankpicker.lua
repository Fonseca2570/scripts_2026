local Banks = require("utils.banks")
local Gui = require("utils.gui")

-- The Bank dropdown: the banks closest to the spot being worked, nearest
-- first, plus Custom with its own x, y and z.
local BankPicker = {}

local Choices = 3
local CustomName = "Custom"

function BankPicker.new(custom)
    return {
        Choice = 1,
        Options = {},
        From = nil,
        Custom = { x = custom.x, y = custom.y, z = custom.z },
    }
end

-- The options follow the spot, including when it is edited by hand.
local function refresh(picker, spot)
    local from = ("%.0f,%.0f"):format(spot.x, spot.y)
    if from == picker.From then
        return
    end
    picker.From = from
    picker.Options = Banks.closest(spot, Choices)
end

local function isCustom(picker)
    return picker.Choice > #picker.Options
end

-- Returns the tile to bank at. Custom returns its own table, so edits in the
-- GUI move the bank.
function BankPicker.bank(picker, spot)
    refresh(picker, spot)
    if isCustom(picker) then
        return picker.Custom
    end
    return picker.Options[picker.Choice].Tile
end

function BankPicker.draw(picker, spot)
    refresh(picker, spot)
    local names = {}
    for i, bank in ipairs(picker.Options) do
        names[i] = ("%s (%.0f tiles)"):format(bank.Name, Banks.distance(bank.Tile, spot))
    end
    names[#names + 1] = CustomName

    local changed, index = ImGui.Combo("Bank", picker.Choice - 1, names)
    if changed then
        picker.Choice = index + 1
    end
    if isCustom(picker) then
        Gui.tile("Custom bank", picker.Custom)
    end
end

return BankPicker
