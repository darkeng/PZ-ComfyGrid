--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
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

function SectionRule.barWidth()
    return math.max(2, math.floor(2.5 * (Style.SCALE or 1) + 0.5))
end

function SectionRule.pad()
    local bar = SectionRule.barWidth() + 2
    return SectionRule.PAD > bar and SectionRule.PAD or bar
end

function SectionRule.plate(el, y, band, lit)
    if el == nil then return end
    local surface = Style.COLORS and Style.COLORS.SURFACE
    if surface == nil then return end
    local tone = lit and surface.cardHi or surface.card
    if tone == nil then return end
    local h = band or Style.FONT_H
    if h < 1 then return end

    el:drawRect(0, y, el.width, h, 1, tone.r, tone.g, tone.b)
end

function SectionRule.card(el, x, y, w, h)
    if el == nil or w == nil or h == nil or w < 2 or h < 2 then return end
    local surface = Style.COLORS and Style.COLORS.SURFACE
    local tone = surface ~= nil and surface.cardHi or nil
    if tone == nil then return end
    el:drawRect(x, y, w, 1, 1, tone.r, tone.g, tone.b)
    el:drawRect(x, y + h - 1, w, 1, 1, tone.r, tone.g, tone.b)
    el:drawRect(x, y + 1, 1, h - 2, 1, tone.r, tone.g, tone.b)
    el:drawRect(x + w - 1, y + 1, 1, h - 2, 1, tone.r, tone.g, tone.b)
end

function SectionRule.activeBar(el, y, band)
    if el == nil then return end
    local surface = Style.COLORS and Style.COLORS.SURFACE
    if surface == nil or surface.accent == nil then return end
    local h = (band or Style.FONT_H) - 2
    if h < 1 then h = 1 end
    el:drawRect(0, y + 1, SectionRule.barWidth(), h, 1,
        surface.accent.r, surface.accent.g, surface.accent.b)
end

SectionRule.TEXT = { r = 0.66, g = 0.66, b = 0.72, a = 0.95 }
SectionRule.LINE = { r = 0.45, g = 0.45, b = 0.50, a = 0.55 }

SectionRule.TEXT_HI = { r = 0.80, g = 0.80, b = 0.84, a = 1.00 }
SectionRule.LINE_HI = { r = 0.60, g = 0.60, b = 0.64, a = 0.80 }

local function lift(target, source, towardWhite, alpha)
    target.r = source.r + (1 - source.r) * towardWhite
    target.g = source.g + (1 - source.g) * towardWhite
    target.b = source.b + (1 - source.b) * towardWhite
    target.a = alpha
end

local function refreshColors()
    local surface = Style.COLORS and Style.COLORS.SURFACE
    if surface == nil then return end
    local text, line = SectionRule.TEXT, SectionRule.LINE
    text.r, text.g, text.b, text.a = surface.accent.r, surface.accent.g,
        surface.accent.b, 0.92
    line.r, line.g, line.b, line.a = surface.line.r, surface.line.g,
        surface.line.b, 0.60
    lift(SectionRule.TEXT_HI, surface.accent, 0.35, 1.00)
    lift(SectionRule.LINE_HI, surface.line, 0.35, 0.85)
end

refreshColors()
if Style.onPaletteChanged ~= nil then
    Style.onPaletteChanged(refreshColors)
end

local cache = {}

function SectionRule.info(key, fallback)
    local info = cache[key]
    if info == nil then
        local label = Text.tr(key, fallback)
        local width = 0
        local textManager = getTextManager and getTextManager() or nil
        if textManager ~= nil then
            local ok, measured = pcall(textManager.MeasureStringX, textManager,
                Style.FONT, label)
            width = ok and measured or 0
        end
        info = { label = label, width = width }
        cache[key] = info
    end
    return info
end

Style.onScaleChanged(function()
    for key in pairs(cache) do cache[key] = nil end
end)

function SectionRule.draw(el, info, y, band, rightPad)
    if el == nil or info == nil then return end
    band = band or Style.FONT_H
    rightPad = rightPad or 0
    local pad = SectionRule.pad()
    local textColor, line = SectionRule.TEXT, SectionRule.LINE
    local textY = y + math.floor((band - Style.FONT_H) / 2) + 1
    el:drawText(info.label, pad, textY, textColor.r, textColor.g, textColor.b,
        textColor.a, Style.FONT)
    local lineX = pad + info.width + 6
    local lineW = el.width - pad - lineX - rightPad
    if lineW > 0 then
        el:drawRect(lineX, y + math.floor(band / 2), lineW, 1,
            line.a, line.r, line.g, line.b)
    end
end
