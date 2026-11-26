local API = require("api")

local Gui = {}

-- Game reads such as API.PlayerCoord don't work from the draw callback, so
-- "Set to my position" only queues the tile and Gui.update fills it in from the
-- script loop.
local pendingTiles = {}

function Gui.indexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then
            return i - 1
        end
    end
    return 0
end

function Gui.combo(label, value, options)
    local changed, index = ImGui.Combo(label, Gui.indexOf(options, value), options)
    if changed then
        return options[index + 1]
    end
    return value
end

function Gui.tile(label, tile)
    ImGui.Text(label)
    ImGui.PushItemWidth(90)
    for _, axis in ipairs({ "x", "y", "z" }) do
        local changed, value = ImGui.InputInt(axis .. "##" .. label, tile[axis], 0, 0)
        if changed then
            tile[axis] = value
        end
        if axis ~= "z" then
            ImGui.SameLine(0, 6)
        end
    end
    ImGui.PopItemWidth()

    if ImGui.Button("Set to my position##" .. label) then
        print("[Gui] Set to my position pressed: " .. label)
        pendingTiles[#pendingTiles + 1] = tile
    end
end

-- Call once per script loop, before anything that reads the tiles.
function Gui.update()
    if #pendingTiles == 0 then
        return
    end
    local coord = API.PlayerCoord()
    print(("[Gui] Setting %d tile(s) to %s,%s,%s"):format(#pendingTiles, tostring(coord.x), tostring(coord.y), tostring(coord.z)))
    for _, tile in ipairs(pendingTiles) do
        tile.x, tile.y, tile.z = coord.x, coord.y, coord.z
    end
    pendingTiles = {}
end

function Gui.text(label, value)
    local changed, text = ImGui.InputText(label, value)
    if changed then
        return text
    end
    return value
end

function Gui.checkbox(label, value)
    local changed, checked = ImGui.Checkbox(label, value)
    if changed then
        return checked
    end
    return value
end

-- Arrival radius (when config.AreaRadius is set) plus the Start/Pause button
-- and status line. Expects state.Running and state.Status.
function Gui.controls(config, state)
    ImGui.Separator()
    if config.AreaRadius ~= nil then
        local changed, radius = ImGui.InputInt("Arrival radius", config.AreaRadius, 1, 5)
        if changed then
            config.AreaRadius = math.max(1, radius)
        end
    end

    if ImGui.Button(state.Running and "Pause" or "Start", 120, 26) then
        state.Running = not state.Running
        state.Status = state.Running and "Starting" or "Paused"
    end
    ImGui.SameLine(0, 12)
    ImGui.Text("Status: " .. state.Status)
end

-- Shows a window that calls draw every frame. Closing the window stops the script.
function Gui.show(title, draw)
    local function drawWindow()
        ImGui.SetNextWindowSize(360, 0, ImGuiCond.Always)
        ImGui.SetNextWindowPos(60, 60, ImGuiCond.FirstUseEver)

        local open, visible = ImGui.Begin(title .. "###" .. title, true)
        if visible then
            local ok, err = pcall(draw)
            if not ok then
                ImGui.TextColored(1.0, 0.3, 0.3, 1.0, "GUI error: " .. tostring(err))
            end
        end
        ImGui.End()

        if not open then
            API.Write_LoopyLoop(false)
        end
    end

    if type(ClearRender) == "function" then
        ClearRender()
    end

    if type(DrawImGui) == "function" then
        DrawImGui(drawWindow)
    end
end

return Gui
