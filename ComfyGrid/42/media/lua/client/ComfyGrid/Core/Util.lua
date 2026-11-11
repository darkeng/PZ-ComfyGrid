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
local Util = {}
ComfyGrid.Core.Util = Util

function Util.clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

function Util.wrapIndex(index, delta, low, high)
    local nextIndex = index + delta
    if nextIndex < low then
        nextIndex = high
    elseif nextIndex > high then
        nextIndex = low
    end
    return nextIndex
end

function Util.isEmpty(tbl)
    for _ in pairs(tbl) do return false end
    return true
end

Util.wipe = table.wipe or function(tableToWipe)
    for key in pairs(tableToWipe) do tableToWipe[key] = nil end
end
