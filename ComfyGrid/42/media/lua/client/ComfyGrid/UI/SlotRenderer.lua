--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/TextureCache"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Blit"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local SlotRenderer = {}
ComfyGrid.UI.SlotRenderer = SlotRenderer

local Style = ComfyGrid.UI.Style

local Blit = ComfyGrid.UI.Blit
local TextureCache = ComfyGrid.Core.TextureCache

local DEFAULT_FILL_ALPHA = 0.725

local tileTexture = TextureCache.lazy("media/textures/comfy_tile.png")

function SlotRenderer.getTileTexture()
    return tileTexture()
end

function SlotRenderer.drawCell(ctx, tint)
    local cell = Style.CELL
    local fillColor = tint or Style.COLORS.EMPTY_CELL
    local tex = tileTexture()
    if tex ~= nil then
        Blit.drawTextureScaled(ctx.view, tex, ctx.x + 1, ctx.y + 1,
            cell - 2, cell - 2, fillColor.a or DEFAULT_FILL_ALPHA,
            fillColor.r, fillColor.g, fillColor.b)
    else
        Blit.drawRect(ctx.view, ctx.x + 1, ctx.y + 1, cell - 2, cell - 2,
            fillColor.a or DEFAULT_FILL_ALPHA, fillColor.r, fillColor.g, fillColor.b)
    end
end

function SlotRenderer.drawHover(ctx, alphaMul)
    local cell = Style.CELL
    local hoverColor = Style.COLORS.HOVER
    local alpha = hoverColor.a * (alphaMul or 1)
    local tex = tileTexture()
    if tex ~= nil then
        Blit.drawTextureScaled(ctx.view, tex, ctx.x + 1, ctx.y + 1,
            cell - 2, cell - 2, alpha, hoverColor.r, hoverColor.g, hoverColor.b)
    else
        Blit.drawRect(ctx.view, ctx.x + 1, ctx.y + 1, cell - 2, cell - 2,
            alpha, hoverColor.r, hoverColor.g, hoverColor.b)
    end
end

local SELECTION_WASH_ALPHA = 0.38

function SlotRenderer.drawSelection(view, x, y)
    local cell = Style.CELL
    local selectedColor = Style.COLORS.SELECTED
    local tex = tileTexture()
    if tex ~= nil then
        Blit.drawTextureScaled(view, tex, x + 1, y + 1, cell - 2, cell - 2,
            SELECTION_WASH_ALPHA, selectedColor.r, selectedColor.g, selectedColor.b)
    else
        local red, green, blue = selectedColor.r, selectedColor.g, selectedColor.b
        local borderWidth = cell - 2
        local alpha = selectedColor.a
        Blit.drawRect(view, x + 1, y + 1, borderWidth, 2, alpha, red, green, blue)
        Blit.drawRect(view, x + 1, y + cell - 3, borderWidth, 2, alpha, red, green, blue)
        Blit.drawRect(view, x + 1, y + 3, 2, cell - 6, alpha, red, green, blue)
        Blit.drawRect(view, x + cell - 3, y + 3, 2, cell - 6, alpha, red, green, blue)
    end
end

local APPLY_RING = 2
local APPLY_CLIP = 3

local function drawBreathingMark(view, x, y, width, height, pulse, color, withWash)
    local phase = pulse or 1
    if withWash then
        local washAlpha = 0.14 + 0.16 * phase
        local tex = tileTexture()
        if tex ~= nil then
            Blit.drawTextureScaled(view, tex, x + 1, y + 1, width - 2, height - 2,
                washAlpha, color.r, color.g, color.b)
        else
            Blit.drawRect(view, x + 1, y + 1, width - 2, height - 2, washAlpha,
                color.r, color.g, color.b)
        end
    end
    local ringAlpha = 0.55 + 0.40 * phase
    local ringThickness = APPLY_RING
    local cornerClip = APPLY_CLIP
    local spanWidth = width - 2 - 2 * cornerClip
    local spanHeight = height - 2 - 2 * cornerClip
    if spanWidth <= 0 or spanHeight <= 0 then return end
    Blit.drawRect(view, x + 1 + cornerClip, y + 1, spanWidth, ringThickness,
        ringAlpha, color.r, color.g, color.b)
    Blit.drawRect(view, x + 1 + cornerClip, y + height - 1 - ringThickness, spanWidth,
        ringThickness, ringAlpha, color.r, color.g, color.b)
    Blit.drawRect(view, x + 1, y + 1 + cornerClip, ringThickness, spanHeight,
        ringAlpha, color.r, color.g, color.b)
    Blit.drawRect(view, x + width - 1 - ringThickness, y + 1 + cornerClip,
        ringThickness, spanHeight, ringAlpha, color.r, color.g, color.b)
end

function SlotRenderer.drawApplyHint(ctx, pulse)
    local color = Style.COLORS.APPLY
    local cell = Style.CELL
    drawBreathingMark(ctx.view, ctx.x, ctx.y, cell, cell, pulse, color, true)
end

local function searchColor()
    return Style.COLORS.SURFACE.accent
end

local markTexture = TextureCache.lazy("media/textures/comfy_mark.png")

function SlotRenderer.drawSearchHint(ctx, pulse)
    local cell = Style.CELL
    local color = searchColor()
    local tex = markTexture()
    if tex == nil then
        drawBreathingMark(ctx.view, ctx.x, ctx.y, cell, cell, pulse, color, true)
        return
    end

    Blit.drawTextureScaled(ctx.view, tex, ctx.x + 1, ctx.y + 1, cell - 2, cell - 2,
        0.55 + 0.40 * (pulse or 1), color.r, color.g, color.b)
end

function SlotRenderer.drawSearchBox(view, x, y, width, height, pulse, withWash)
    drawBreathingMark(view, x, y, width, height, pulse, searchColor(), withWash)
end

local HIGHLIGHT_WASH = 0.22
local HIGHLIGHT_RING_A = 0.75
local HIGHLIGHT_RING = 2
local HIGHLIGHT_CLIP = 3

function SlotRenderer.drawHighlight(ctx)
    local cell = Style.CELL
    local view = ctx.view
    local x, y = ctx.x, ctx.y
    local highlight = Style.COLORS.HIGHLIGHT
    local red, green, blue = highlight.r, highlight.g, highlight.b
    local tex = tileTexture()
    if tex ~= nil then
        view:drawTextureScaled(tex, x + 1, y + 1, cell - 2, cell - 2,
            HIGHLIGHT_WASH, red, green, blue)
    else
        view:drawRect(x + 1, y + 1, cell - 2, cell - 2,
            HIGHLIGHT_WASH, red, green, blue)
    end

    local ringThickness = HIGHLIGHT_RING
    local cornerClip = HIGHLIGHT_CLIP
    local span = cell - 2 - 2 * cornerClip
    if span <= 0 then return end
    local ringAlpha = HIGHLIGHT_RING_A
    view:drawRect(x + 1 + cornerClip, y + 1, span, ringThickness,
        ringAlpha, red, green, blue)
    view:drawRect(x + 1 + cornerClip, y + cell - 1 - ringThickness, span,
        ringThickness, ringAlpha, red, green, blue)
    view:drawRect(x + 1, y + 1 + cornerClip, ringThickness, span,
        ringAlpha, red, green, blue)
    view:drawRect(x + cell - 1 - ringThickness, y + 1 + cornerClip,
        ringThickness, span, ringAlpha, red, green, blue)
end

local pulseUnsupported = false
function SlotRenderer.applyPulse()
    if pulseUnsupported then return 1 end
    local ok, nowMs = pcall(getTimestampMs)
    if not ok or type(nowMs) ~= "number" then
        pulseUnsupported = true
        return 1
    end
    return 0.5 + 0.5 * math.sin(nowMs * 0.0052)
end

function SlotRenderer.drawSocket(ctx, size)
    local cell = size or Style.CELL
    local view = ctx.view
    local x = ctx.x
    local y = ctx.y
    local colors = Style.COLORS
    local fill = colors.SOCKET_FILL
    local tex = tileTexture()
    if tex ~= nil then
        view:drawTextureScaled(tex, x + 1, y + 1, cell - 2, cell - 2,
            fill.a, fill.r, fill.g, fill.b)
    else
        view:drawRect(x + 1, y + 1, cell - 2, cell - 2,
            fill.a, fill.r, fill.g, fill.b)
    end
    local edge = colors.SOCKET_EDGE
    local alpha, red, green, blue = edge.a, edge.r, edge.g, edge.b
    local armLength = math.floor(cell * 0.16)
    if armLength < 4 then armLength = 4 end
    local thickness = math.floor(Style.SCALE + 0.5)
    if thickness < 1 then thickness = 1 end
    local x0 = x + 3
    local y0 = y + 3
    local x1 = x + cell - 3
    local y1 = y + cell - 3
    view:drawRect(x0, y0, armLength, thickness, alpha, red, green, blue)
    view:drawRect(x0, y0, thickness, armLength, alpha, red, green, blue)
    view:drawRect(x1 - armLength, y0, armLength, thickness, alpha, red, green, blue)
    view:drawRect(x1 - thickness, y0, thickness, armLength, alpha, red, green, blue)
    view:drawRect(x0, y1 - thickness, armLength, thickness, alpha, red, green, blue)
    view:drawRect(x0, y1 - armLength, thickness, armLength, alpha, red, green, blue)
    view:drawRect(x1 - armLength, y1 - thickness, armLength, thickness,
        alpha, red, green, blue)
    view:drawRect(x1 - thickness, y1 - armLength, thickness, armLength,
        alpha, red, green, blue)
end

function SlotRenderer.drawGhost(view, tex, x, y, size)
    local cell = size or Style.CELL
    local texW = tex:getWidth()
    local texH = tex:getHeight()
    if not texW or not texH or texW <= 0 or texH <= 0 then return end
    local largest = texW > texH and texW or texH
    local scale = (cell * 0.62) / largest
    local drawWidth = texW * scale
    local drawHeight = texH * scale
    local ghost = Style.COLORS.SOCKET_GHOST
    view:drawTextureScaled(tex, x + (cell - drawWidth) * 0.5,
        y + (cell - drawHeight) * 0.5,
        drawWidth, drawHeight, ghost.a, ghost.r, ghost.g, ghost.b)
end

local NAME_CHIP_EDGE_ALPHA = 0.6

function SlotRenderer.drawNameChip(view, info, x, y, font)
    if info == nil or font == nil then return end
    local cell = Style.CELL
    local chipW = (info.width or 0) + 10
    local chipH = Style.FONT_H + 2
    local chipX = x + math.floor((cell - chipW) * 0.5)
    local chipY = y + math.floor((cell - chipH) * 0.5)
    local colors = Style.COLORS
    local backing, edge, text = colors.NAME_CHIP_BG, colors.SOCKET_EDGE,
        colors.NAME_CHIP_TEXT
    view:drawRect(chipX, chipY, chipW, chipH,
        backing.a, backing.r, backing.g, backing.b)
    view:drawRectBorder(chipX, chipY, chipW, chipH,
        NAME_CHIP_EDGE_ALPHA, edge.r, edge.g, edge.b)
    view:drawTextCentre(info.label, x + cell * 0.5, chipY + 1,
        text.r, text.g, text.b, text.a, font)
end
