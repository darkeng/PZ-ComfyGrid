--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local Blit = {}
ComfyGrid.UI.Blit = Blit

function Blit.drawTextureScaled(view, tex, x, y, w, h, alpha, red, green, blue)
    local javaObject = view.javaObject
    if javaObject == nil then return end
    if red == nil then
        javaObject:DrawTextureScaled(tex, x, y, w, h, alpha)
    else
        javaObject:DrawTextureScaledColor(tex, x, y, w, h, red, green, blue, alpha)
    end
end

function Blit.drawRect(view, x, y, w, h, alpha, red, green, blue)
    local javaObject = view.javaObject
    if javaObject == nil or view.isCollapsed then return end
    javaObject:DrawTextureScaledColor(nil, x, y, w, h, red, green, blue, alpha)
end

function Blit.drawText(view, str, x, y, red, green, blue, alpha, font)
    local javaObject = view.javaObject
    if javaObject == nil or view.isCollapsed then return end
    javaObject:DrawText(font or UIFont.Small, str, x, y, red, green, blue, alpha)
end
