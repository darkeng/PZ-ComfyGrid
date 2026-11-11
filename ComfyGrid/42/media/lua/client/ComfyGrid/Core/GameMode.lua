--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.10.0
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
    if not okCore or core == nil or core.isTutorial == nil then
        return false
    end
    local okMode, tutorial = pcall(core.isTutorial, core)
    return okMode and tutorial == true
end

return GameMode
