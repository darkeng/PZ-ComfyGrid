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
local TextureCache = {}
ComfyGrid.Core.TextureCache = TextureCache

local textureByPath = {}

function TextureCache.get(path)
    if path == nil then return nil end
    local cached = textureByPath[path]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end
    local ok, texture = pcall(getTexture, path)
    if ok and texture then
        textureByPath[path] = texture
        return texture
    end
    textureByPath[path] = false
    return nil
end

function TextureCache.lazy(path)
    local texture = nil
    local resolved = false
    return function()
        if not resolved then
            resolved = true
            texture = TextureCache.get(path)
        end
        return texture
    end
end
