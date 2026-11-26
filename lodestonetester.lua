local API = require("api")
local Gui = require("utils.gui")
local LODESTONES = require("lodestones")

-- Pick a lodestone and press Teleport to check its interface id and tile in
-- game. The teleport and the position check run in the main loop, since game
-- reads don't work from the draw callback.
local Names = {}
for name in pairs(LODESTONES) do
    Names[#Names + 1] = name
end
table.sort(Names)

local State = {
    Selected = Names[1],
    Pending = nil,
    Status = "Idle",
    AtSelected = false,
}

Gui.show("Lodestone Tester", function()
    ImGui.SeparatorText("Lodestone")
    State.Selected = Gui.combo("Lodestone", State.Selected, Names)

    local lode = LODESTONES[State.Selected]
    ImGui.Text(("Interface id %d, tile %d,%d,%d"):format(lode.id, lode.loc.x, lode.loc.y, lode.loc.z))
    ImGui.Text("At this lodestone: " .. (State.AtSelected and "yes" or "no"))

    if ImGui.Button("Teleport", 120, 26) and State.Pending == nil then
        State.Pending = State.Selected
    end
    ImGui.SameLine(0, 12)
    ImGui.Text("Status: " .. State.Status)
end)

API.Write_LoopyLoop(true)

while API.Read_LoopyLoop() do
    if State.Pending ~= nil then
        local name = State.Pending
        State.Status = "Teleporting to " .. name
        local arrived = LODESTONES[name].Teleport()
        State.Status = (arrived and "Arrived at " or "Failed: ") .. name
        State.Pending = nil
    end
    State.AtSelected = LODESTONES[State.Selected].IsAtLocation()
    API.RandomSleep2(200, 100, 100)
end
