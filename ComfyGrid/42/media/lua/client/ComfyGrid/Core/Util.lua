--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.4.1
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"

ComfyGrid = ComfyGrid or {}
ComfyGrid.Core = ComfyGrid.Core or {}
local Util = {}
ComfyGrid.Core.Util = Util

function Util.clamp(v, min, max)
    if v < min then return min end
    if v > max then return max end
    return v
end

function Util.round(v, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(v * mult + 0.5) / mult
end

function Util.tableCount(t)
    if t == nil then return 0 end
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

function Util.isEmpty(t)
    return t == nil or next(t) == nil
end

function Util.shallowCopy(t)
    if t == nil then return nil end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = v
    end
    return copy
end
