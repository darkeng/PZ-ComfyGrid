--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.3
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Draw"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
ComfyGrid.UI.Chrome = ComfyGrid.UI.Chrome or {}
local SectionCaret = {}
ComfyGrid.UI.Chrome.SectionCaret = SectionCaret

local Style = ComfyGrid.UI.Style
local Draw = ComfyGrid.UI.Draw

local CARET_FONT_RATIO = 0.55
local CARET_MIN_SIDE = 7

local LABEL_GAP = 4

function SectionCaret.size()
    local side = math.floor((Style.FONT_H or 16) * CARET_FONT_RATIO + 0.5)
    if side < CARET_MIN_SIDE then side = CARET_MIN_SIDE end
    return side
end

function SectionCaret.advance()
    local gap = math.max(2, math.floor(LABEL_GAP * (Style.SCALE or 1) + 0.5))
    return SectionCaret.size() + gap
end

function SectionCaret.draw(element, x, y, band, collapsed, color)
    if element == nil or color == nil then return 0 end
    local texture = collapsed and Draw.caretClosedTexture()
        or Draw.caretOpenTexture()
    if texture == nil then return 0 end
    local side = SectionCaret.size()
    local top = y + math.floor((band - side) / 2)
    element:drawTextureScaled(texture, x, top, side, side,
        color.a, color.r, color.g, color.b)
    return SectionCaret.advance()
end

function SectionCaret.contains(pointX, pointY, x, y, band)
    return pointX >= x and pointX < x + SectionCaret.advance()
        and pointY >= y and pointY < y + band
end
