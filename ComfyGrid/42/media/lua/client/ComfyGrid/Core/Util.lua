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
local Util = {}
ComfyGrid.Core.Util = Util

function Util.clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

Util.wipe = table.wipe or function(tableToWipe)
    for key in pairs(tableToWipe) do tableToWipe[key] = nil end
end
