--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.5.3
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Text"
require "ComfyGrid/UI/Style"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
ComfyGrid.UI.Chrome = ComfyGrid.UI.Chrome or {}
local SectionRule = {}
ComfyGrid.UI.Chrome.SectionRule = SectionRule

local Style = ComfyGrid.UI.Style
local Text = ComfyGrid.Core.Text

SectionRule.PAD = 4

local _surf = Style.COLORS and Style.COLORS.SURFACE
SectionRule.TEXT = _surf
    and { r = _surf.accent.r, g = _surf.accent.g, b = _surf.accent.b, a = 0.92 }
    or { r = 0.66, g = 0.66, b = 0.72, a = 0.95 }
SectionRule.LINE = _surf
    and { r = _surf.line.r, g = _surf.line.g, b = _surf.line.b, a = 0.60 }
    or { r = 0.45, g = 0.45, b = 0.50, a = 0.55 }

local cache = {}

function SectionRule.info(key, fallback)
    local info = cache[key]
    if info == nil then
        local label = Text.tr(key, fallback)
        local width = 0
        local tm = getTextManager and getTextManager() or nil
        if tm ~= nil then
            local ok, w = pcall(tm.MeasureStringX, tm, Style.FONT, label)
            width = ok and w or 0
        end
        info = { label = label, width = width }
        cache[key] = info
    end
    return info
end

Style.onScaleChanged(function()
    for k in pairs(cache) do cache[k] = nil end
end)

function SectionRule.draw(el, info, y, band, rightPad)
    if el == nil or info == nil then return end
    band = band or Style.FONT_H
    rightPad = rightPad or 0
    local pad = SectionRule.PAD
    local t, line = SectionRule.TEXT, SectionRule.LINE
    local textY = y + math.floor((band - Style.FONT_H) / 2) + 1
    el:drawText(info.label, pad, textY, t.r, t.g, t.b, t.a, Style.FONT)
    local lineX = pad + info.width + 6
    local lineW = el.width - pad - lineX - rightPad
    if lineW > 0 then
        el:drawRect(lineX, y + math.floor(band / 2), lineW, 1,
            line.a, line.r, line.g, line.b)
    end
end
