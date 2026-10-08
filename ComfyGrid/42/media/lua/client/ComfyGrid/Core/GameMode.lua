--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Core = ComfyGrid.Core or {}
local GameMode = {}
ComfyGrid.Core.GameMode = GameMode

function GameMode.isTutorial()
    local okCore, core = pcall(getCore)
    if not okCore or core == nil or core.getGameMode == nil then
        return false
    end
    local okMode, mode = pcall(core.getGameMode, core)
    return okMode and tostring(mode) == "Tutorial"
end

return GameMode
