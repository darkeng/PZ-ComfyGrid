--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.1
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local Blit = {}
ComfyGrid.UI.Blit = Blit

function Blit.tex(view, tex, x, y, w, h, a, r, g, b)
    local jo = view.javaObject
    if jo == nil then return end
    if r == nil then
        jo:DrawTextureScaled(tex, x, y, w, h, a)
    else
        jo:DrawTextureScaledColor(tex, x, y, w, h, r, g, b, a)
    end
end

function Blit.rect(view, x, y, w, h, a, r, g, b)
    local jo = view.javaObject
    if jo == nil or view.isCollapsed then return end
    jo:DrawTextureScaledColor(nil, x, y, w, h, r, g, b, a)
end

function Blit.text(view, str, x, y, r, g, b, a, font)
    local jo = view.javaObject
    if jo == nil or view.isCollapsed then return end
    jo:DrawText(font or UIFont.Small, str, x, y, r, g, b, a)
end
