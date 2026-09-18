--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.4
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"

ComfyGrid = ComfyGrid or {}
ComfyGrid.Core = ComfyGrid.Core or {}
local TextureCache = {}
ComfyGrid.Core.TextureCache = TextureCache

local cache = {}

function TextureCache.get(path)
    if path == nil then return nil end
    local cached = cache[path]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end
    local ok, tex = pcall(getTexture, path)
    if ok and tex then
        cache[path] = tex
        return tex
    end
    cache[path] = false
    return nil
end
