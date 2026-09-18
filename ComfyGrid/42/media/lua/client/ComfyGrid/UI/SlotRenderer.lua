--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.3
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/UI/Style"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local SlotRenderer = {}
ComfyGrid.UI.SlotRenderer = SlotRenderer

local Style = ComfyGrid.UI.Style

local FALLBACK_CELL = { r = 0.16, g = 0.16, b = 0.16, a = 0.85 }
local FALLBACK_HOVER = { r = 1, g = 1, b = 1, a = 0.25 }

local DEFAULT_FILL_ALPHA = 0.725

local tileTex = nil
local tileTexMissing = false
local function tileTexture()
    if tileTex == nil and not tileTexMissing then
        tileTex = getTexture and getTexture("media/textures/comfy_tile.png") or nil
        if tileTex == nil then tileTexMissing = true end
    end
    return tileTex
end

function SlotRenderer.getTileTexture()
    return tileTexture()
end

function SlotRenderer.drawCell(ctx, tint)
    local cell = Style.CELL
    local colors = Style.COLORS
    local c = tint or (colors and colors.EMPTY_CELL) or FALLBACK_CELL
    local tex = tileTexture()
    if tex ~= nil then
        ctx.view:drawTextureScaled(tex, ctx.x + 1, ctx.y + 1,
            cell - 2, cell - 2, c.a or DEFAULT_FILL_ALPHA, c.r, c.g, c.b)
    else
        ctx.view:drawRect(ctx.x + 1, ctx.y + 1, cell - 2, cell - 2,
            c.a or DEFAULT_FILL_ALPHA, c.r, c.g, c.b)
    end
end

function SlotRenderer.drawHover(ctx, alphaMul)
    local cell = Style.CELL
    local colors = Style.COLORS
    local c = (colors and colors.HOVER) or FALLBACK_HOVER
    local a = (c.a or FALLBACK_HOVER.a) * (alphaMul or 1)
    local tex = tileTexture()
    if tex ~= nil then
        ctx.view:drawTextureScaled(tex, ctx.x + 1, ctx.y + 1,
            cell - 2, cell - 2, a, c.r, c.g, c.b)
    else
        ctx.view:drawRect(ctx.x + 1, ctx.y + 1, cell - 2, cell - 2,
            a, c.r, c.g, c.b)
    end
end

local FALLBACK_SELECTED = { r = 0.35, g = 0.75, b = 1.0, a = 0.9 }
local SELECTION_WASH_ALPHA = 0.38

function SlotRenderer.drawSelection(view, x, y)
    local cell = Style.CELL
    local colors = Style.COLORS
    local c = (colors and colors.SELECTED) or FALLBACK_SELECTED
    local tex = tileTexture()
    if tex ~= nil then
        view:drawTextureScaled(tex, x + 1, y + 1, cell - 2, cell - 2,
            SELECTION_WASH_ALPHA, c.r, c.g, c.b)
    else
        local bw = cell - 2
        local a = c.a or 0.9
        view:drawRect(x + 1, y + 1, bw, 2, a, c.r, c.g, c.b)
        view:drawRect(x + 1, y + cell - 3, bw, 2, a, c.r, c.g, c.b)
        view:drawRect(x + 1, y + 3, 2, cell - 6, a, c.r, c.g, c.b)
        view:drawRect(x + cell - 3, y + 3, 2, cell - 6, a, c.r, c.g, c.b)
    end
end

local FALLBACK_APPLY = { r = 0.42, g = 0.92, b = 0.50, a = 0.90 }
local APPLY_RING = 2
local APPLY_CLIP = 3

function SlotRenderer.drawApplyHint(ctx, pulse)
    local cell = Style.CELL
    local colors = Style.COLORS
    local c = (colors and colors.APPLY) or FALLBACK_APPLY
    local view = ctx.view
    local x, y = ctx.x, ctx.y
    local p = pulse or 1
    local tex = tileTexture()
    local wash = 0.14 + 0.16 * p
    if tex ~= nil then
        view:drawTextureScaled(tex, x + 1, y + 1, cell - 2, cell - 2,
            wash, c.r, c.g, c.b)
    else
        view:drawRect(x + 1, y + 1, cell - 2, cell - 2, wash, c.r, c.g, c.b)
    end
    local a = 0.55 + 0.40 * p
    local t = APPLY_RING
    local k = APPLY_CLIP
    local span = cell - 2 - 2 * k
    if span <= 0 then return end
    view:drawRect(x + 1 + k, y + 1, span, t, a, c.r, c.g, c.b)
    view:drawRect(x + 1 + k, y + cell - 1 - t, span, t, a, c.r, c.g, c.b)
    view:drawRect(x + 1, y + 1 + k, t, span, a, c.r, c.g, c.b)
    view:drawRect(x + cell - 1 - t, y + 1 + k, t, span, a, c.r, c.g, c.b)
end

local HIGHLIGHT = { r = 1.0, g = 1.0, b = 1.0 }
local HIGHLIGHT_WASH = 0.22
local HIGHLIGHT_RING_A = 0.75
local HIGHLIGHT_RING = 2
local HIGHLIGHT_CLIP = 3

function SlotRenderer.drawHighlight(ctx)
    local cell = Style.CELL
    local view = ctx.view
    local x, y = ctx.x, ctx.y
    local c = HIGHLIGHT
    local tex = tileTexture()
    if tex ~= nil then
        view:drawTextureScaled(tex, x + 1, y + 1, cell - 2, cell - 2,
            HIGHLIGHT_WASH, c.r, c.g, c.b)
    else
        view:drawRect(x + 1, y + 1, cell - 2, cell - 2,
            HIGHLIGHT_WASH, c.r, c.g, c.b)
    end

    local t = HIGHLIGHT_RING
    local k = HIGHLIGHT_CLIP
    local span = cell - 2 - 2 * k
    if span <= 0 then return end
    local a = HIGHLIGHT_RING_A
    view:drawRect(x + 1 + k, y + 1, span, t, a, c.r, c.g, c.b)
    view:drawRect(x + 1 + k, y + cell - 1 - t, span, t, a, c.r, c.g, c.b)
    view:drawRect(x + 1, y + 1 + k, t, span, a, c.r, c.g, c.b)
    view:drawRect(x + cell - 1 - t, y + 1 + k, t, span, a, c.r, c.g, c.b)
end

local pulseUnsupported = false
function SlotRenderer.applyPulse()
    if pulseUnsupported then return 1 end
    local ok, ms = pcall(getTimestampMs)
    if not ok or type(ms) ~= "number" then
        pulseUnsupported = true
        return 1
    end
    return 0.5 + 0.5 * math.sin(ms * 0.0052)
end

local SOCKET_FILL = { r = 0.115, g = 0.11, b = 0.135, a = 1.0 }
local SOCKET_EDGE = { r = 0.44, g = 0.39, b = 0.29, a = 0.8 }

function SlotRenderer.drawSocket(ctx, size)
    local cell = size or Style.CELL
    local view = ctx.view
    local x = ctx.x
    local y = ctx.y
    local f = SOCKET_FILL
    local tex = tileTexture()
    if tex ~= nil then
        view:drawTextureScaled(tex, x + 1, y + 1, cell - 2, cell - 2,
            f.a, f.r, f.g, f.b)
    else
        view:drawRect(x + 1, y + 1, cell - 2, cell - 2, f.a, f.r, f.g, f.b)
    end
    local e = SOCKET_EDGE
    local L = math.floor(cell * 0.16)
    if L < 4 then L = 4 end
    local t = math.floor(Style.SCALE + 0.5)
    if t < 1 then t = 1 end
    local x0 = x + 3
    local y0 = y + 3
    local x1 = x + cell - 3
    local y1 = y + cell - 3
    view:drawRect(x0, y0, L, t, e.a, e.r, e.g, e.b)
    view:drawRect(x0, y0, t, L, e.a, e.r, e.g, e.b)
    view:drawRect(x1 - L, y0, L, t, e.a, e.r, e.g, e.b)
    view:drawRect(x1 - t, y0, t, L, e.a, e.r, e.g, e.b)
    view:drawRect(x0, y1 - t, L, t, e.a, e.r, e.g, e.b)
    view:drawRect(x0, y1 - L, t, L, e.a, e.r, e.g, e.b)
    view:drawRect(x1 - L, y1 - t, L, t, e.a, e.r, e.g, e.b)
    view:drawRect(x1 - t, y1 - L, t, L, e.a, e.r, e.g, e.b)
end

local GHOST_ALPHA = 0.30
local GHOST_R, GHOST_G, GHOST_B = 0.72, 0.72, 0.78

function SlotRenderer.drawGhost(view, tex, x, y, size)
    local cell = size or Style.CELL
    local texW = tex:getWidth()
    local texH = tex:getHeight()
    if not texW or not texH or texW <= 0 or texH <= 0 then return end
    local largest = texW > texH and texW or texH
    local sc = (cell * 0.62) / largest
    local dw = texW * sc
    local dh = texH * sc
    view:drawTextureScaled(tex, x + (cell - dw) * 0.5, y + (cell - dh) * 0.5,
        dw, dh, GHOST_ALPHA, GHOST_R, GHOST_G, GHOST_B)
end

function SlotRenderer.drawNameChip(view, info, x, y, font)
    if info == nil or font == nil then return end
    local cell = Style.CELL
    local chipW = (info.width or 0) + 10
    local chipH = Style.FONT_H + 2
    local cx = x + math.floor((cell - chipW) * 0.5)
    local cy = y + math.floor((cell - chipH) * 0.5)
    view:drawRect(cx, cy, chipW, chipH, 0.88, 0.05, 0.05, 0.06)
    view:drawRectBorder(cx, cy, chipW, chipH, 0.6, 0.44, 0.39, 0.29)
    view:drawTextCentre(info.label, x + cell * 0.5, cy + 1,
        0.92, 0.92, 0.95, 1, font)
end
