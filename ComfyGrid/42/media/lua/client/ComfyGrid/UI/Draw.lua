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
local Draw = {}
ComfyGrid.UI.Draw = Draw

local TextureCache = ComfyGrid.Core.TextureCache
local Style = ComfyGrid.UI.Style
local Blit = ComfyGrid.UI.Blit
local floor = math.floor
local min = math.min

local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos

local corners = nil
local cornersMissing = false
local function cornerSet()
    if corners == nil and not cornersMissing then
        local tl = TextureCache.get("media/textures/comfy_cnr_tl.png")
        local tr = TextureCache.get("media/textures/comfy_cnr_tr.png")
        local bl = TextureCache.get("media/textures/comfy_cnr_bl.png")
        local br = TextureCache.get("media/textures/comfy_cnr_br.png")
        if tl and tr and bl and br then
            corners = { tl = tl, tr = tr, bl = bl, br = br }
        else
            cornersMissing = true
        end
    end
    return corners
end

function Draw.roundRect(view, x, y, w, h, radius, alpha, color)
    local cornerTextures = cornerSet()
    if cornerTextures == nil or radius == nil or radius < 2 then
        Blit.drawRect(view, x, y, w, h, alpha, color.r, color.g, color.b)
        return
    end
    local half = floor(min(w, h) * 0.5)
    if radius > half then radius = half end
    local red, green, blue = color.r, color.g, color.b
    Blit.drawTextureScaled(view, cornerTextures.tl, x, y, radius, radius,
        alpha, red, green, blue)
    Blit.drawTextureScaled(view, cornerTextures.tr, x + w - radius, y,
        radius, radius, alpha, red, green, blue)
    Blit.drawTextureScaled(view, cornerTextures.bl, x, y + h - radius,
        radius, radius, alpha, red, green, blue)
    Blit.drawTextureScaled(view, cornerTextures.br, x + w - radius,
        y + h - radius, radius, radius, alpha, red, green, blue)
    if w > 2 * radius then
        Blit.drawRect(view, x + radius, y, w - 2 * radius, radius,
            alpha, red, green, blue)
        Blit.drawRect(view, x + radius, y + h - radius, w - 2 * radius, radius,
            alpha, red, green, blue)
    end
    if h > 2 * radius then
        Blit.drawRect(view, x, y + radius, w, h - 2 * radius,
            alpha, red, green, blue)
    end
end

function Draw.roundFrame(view, x, y, w, h, radius, alpha, border, fill, fillAlpha)
    Draw.roundRect(view, x, y, w, h, radius, alpha, border)
    Draw.roundRect(view, x + 1, y + 1, w - 2, h - 2, radius - 1,
        fillAlpha or alpha, fill)
end

local glowTexture = TextureCache.lazy("media/textures/comfy_glow.png")

function Draw.shadow(view, x, y, w, h, spread, alpha)
    local glowTex = glowTexture()
    if glowTex == nil then return end
    local down = floor(spread * 0.2 + 0.5)
    local ink = Style.COLORS.SHADOW
    view:drawTextureScaled(glowTex, x - spread, y - spread + down,
        w + spread * 2, h + spread * 2, alpha, ink.r, ink.g, ink.b)
end

local gradTexture = TextureCache.lazy("media/textures/comfy_grad_v.png")

function Draw.sheen(view, x, y, w, h, alpha, color)
    local gradTex = gradTexture()
    if gradTex == nil then return end
    view:drawTextureScaled(gradTex, x, y, w, h, alpha, color.r, color.g, color.b)
end

function Draw.headerLine(view, x, y, w, sheenH, colors)
    local surface = colors and colors.SURFACE
    if surface == nil then return end
    if sheenH and sheenH > 0 then
        Draw.sheen(view, x, y - sheenH, w, sheenH, 0.06, surface.accent)
    end
    view:drawRect(x, y, w, 1, Style.CHROME_LINE_ALPHA,
        surface.line.r, surface.line.g, surface.line.b)
end

local dotTexture = TextureCache.lazy("media/textures/comfy_dot.png")

function Draw.disc(view, x, y, diameter, alpha, color)
    local dotTex = dotTexture()
    if dotTex ~= nil then
        view:drawTextureScaled(dotTex, x, y, diameter, diameter, alpha,
            color.r, color.g, color.b)
    else
        Draw.roundRect(view, x, y, diameter, diameter, floor(diameter * 0.5),
            alpha, color)
    end
end

function Draw.pill(view, x, y, w, h, alpha, color)
    local dotTex = dotTexture()
    if dotTex == nil or w < h then
        Draw.roundRect(view, x, y, w, h, floor(h * 0.5), alpha, color)
        return
    end
    local red, green, blue = color.r, color.g, color.b
    Blit.drawTextureScaled(view, dotTex, x, y, h, h, alpha, red, green, blue)
    Blit.drawTextureScaled(view, dotTex, x + w - h, y, h, h, alpha, red, green, blue)
    local half = floor(h * 0.5)
    if w > 2 * half then
        Blit.drawRect(view, x + half, y, w - 2 * half, h, alpha, red, green, blue)
    end
end

function Draw.pillFrame(view, x, y, w, h, alpha, border, fill)
    Draw.pill(view, x, y, w, h, alpha, border)
    Draw.pill(view, x + 1, y + 1, w - 2, h - 2, alpha, fill)
end

function Draw.pie(view, centerX, centerY, radius, sweep, alpha, color)
    if radius < 1 or sweep <= 0 then return end
    if sweep >= 6.2831853 then
        Draw.disc(view, floor(centerX - radius), floor(centerY - radius),
            floor(radius * 2), alpha, color)
        return
    end
    local wide = sweep > 3.1415927
    local endX, endY = sin(sweep), -cos(sweep)
    local radiusInt = floor(radius)
    for rowOffset = -radiusInt, radiusInt do
        local half = sqrt(radius * radius - rowOffset * rowOffset)
        local firstColumn = -floor(half)
        local lastColumn = floor(half)
        local runStart = nil
        for columnOffset = firstColumn, lastColumn + 1 do
            local inside = false
            if columnOffset <= lastColumn then
                local endCross = endX * rowOffset - endY * columnOffset
                if wide then
                    inside = columnOffset >= 0 or endCross <= 0
                else
                    inside = columnOffset >= 0 and endCross <= 0
                end
            end
            if inside and runStart == nil then
                runStart = columnOffset
            elseif not inside and runStart ~= nil then
                view:drawRect(floor(centerX + runStart), floor(centerY + rowOffset),
                    columnOffset - runStart, 1, alpha, color.r, color.g, color.b)
                runStart = nil
            end
        end
    end
end

local glyphTex = {}
local glyphMissing = {}

function Draw.glyphTexture(id)
    if id == nil or glyphMissing[id] then return nil end
    local texture = glyphTex[id]
    if texture == nil then
        texture = TextureCache.get("media/textures/comfy_" .. id .. ".png")
        if texture == nil then
            glyphMissing[id] = true
            return nil
        end
        glyphTex[id] = texture
    end
    return texture
end

function Draw.closeTexture()
    return Draw.glyphTexture("close")
end

function Draw.sortTexture()
    return Draw.glyphTexture("sort")
end

function Draw.stowTexture()
    return Draw.glyphTexture("stow")
end

function Draw.emptyTexture()
    return Draw.glyphTexture("empty")
end

function Draw.trashTexture()
    return Draw.glyphTexture("trash")
end

function Draw.spreadTexture()
    return Draw.glyphTexture("spread")
end

function Draw.layersTexture()
    return Draw.glyphTexture("layers")
end

function Draw.floorTexture()
    return Draw.glyphTexture("floor")
end

function Draw.moreTexture()
    return Draw.glyphTexture("more")
end

local bakedTex = {}

local function bakedTexture(name)

    local LiveStyle = ComfyGrid.UI and ComfyGrid.UI.Style

    local LiveThemes = ComfyGrid.UI and ComfyGrid.UI.Themes
    local fallback = (LiveThemes ~= nil and LiveThemes.DEFAULT) or "amber"
    local theme = (LiveStyle ~= nil and LiveStyle.THEME) or fallback
    local key = name .. "|" .. theme
    local tex = bakedTex[key]
    if tex ~= nil then return tex or nil end
    local path = "media/textures/" .. name
        .. (theme == fallback and "" or ("_" .. theme)) .. ".png"
    tex = TextureCache.get(path)
    if tex == nil and theme ~= fallback then

        tex = TextureCache.get("media/textures/" .. name .. ".png")
    end
    bakedTex[key] = tex or false
    return tex
end

function Draw.titlebarTexture()
    return bakedTexture("comfy_titlebar")
end

function Draw.pinTexture()
    return Draw.glyphTexture("pin")
end

function Draw.gripTexture()
    return bakedTexture("comfy_grip")
end

function Draw.gearTexture()
    return Draw.glyphTexture("gear")
end

function Draw.personTexture()
    return Draw.glyphTexture("person")
end

function Draw.dockTexture()
    return Draw.glyphTexture("dock")
end

function Draw.delta()
    local elapsedMs = UIManager.getMillisSinceLastRender()
    local frames = elapsedMs / 33.3
    if frames > 3 then frames = 3 end
    return frames
end

function Draw.glide(current, target, rate)
    local step = rate * Draw.delta()
    if step > 1 then step = 1 end
    local glided = current + (target - current) * step
    local diff = glided - target
    if diff < 0.002 and diff > -0.002 then return target end
    return glided
end
