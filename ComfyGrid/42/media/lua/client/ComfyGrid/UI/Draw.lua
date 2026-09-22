--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.8
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/TextureCache"
require "ComfyGrid/UI/Style"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local Draw = {}
ComfyGrid.UI.Draw = Draw

local TextureCache = ComfyGrid.Core.TextureCache
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

function Draw.roundRect(el, x, y, w, h, r, a, c)
    local cs = cornerSet()
    if cs == nil or r == nil or r < 2 then
        el:drawRect(x, y, w, h, a, c.r, c.g, c.b)
        return
    end
    local half = floor(min(w, h) * 0.5)
    if r > half then r = half end
    el:drawTextureScaled(cs.tl, x, y, r, r, a, c.r, c.g, c.b)
    el:drawTextureScaled(cs.tr, x + w - r, y, r, r, a, c.r, c.g, c.b)
    el:drawTextureScaled(cs.bl, x, y + h - r, r, r, a, c.r, c.g, c.b)
    el:drawTextureScaled(cs.br, x + w - r, y + h - r, r, r, a, c.r, c.g, c.b)
    if w > 2 * r then
        el:drawRect(x + r, y, w - 2 * r, r, a, c.r, c.g, c.b)
        el:drawRect(x + r, y + h - r, w - 2 * r, r, a, c.r, c.g, c.b)
    end
    if h > 2 * r then
        el:drawRect(x, y + r, w, h - 2 * r, a, c.r, c.g, c.b)
    end
end

function Draw.roundFrame(el, x, y, w, h, r, a, border, fill, aFill)
    Draw.roundRect(el, x, y, w, h, r, a, border)
    Draw.roundRect(el, x + 1, y + 1, w - 2, h - 2, r - 1, aFill or a, fill)
end

local glowTex = nil
local glowTexMissing = false
local function glowTexture()
    if glowTex == nil and not glowTexMissing then
        glowTex = TextureCache.get("media/textures/comfy_glow.png")
        if glowTex == nil then glowTexMissing = true end
    end
    return glowTex
end

function Draw.shadow(el, x, y, w, h, spread, a)
    local g = glowTexture()
    if g == nil then return end
    local down = floor(spread * 0.2 + 0.5)
    el:drawTextureScaled(g, x - spread, y - spread + down,
        w + spread * 2, h + spread * 2, a, 0, 0, 0)
end

local gradTex = nil
local gradTexMissing = false
local function gradTexture()
    if gradTex == nil and not gradTexMissing then
        gradTex = TextureCache.get("media/textures/comfy_grad_v.png")
        if gradTex == nil then gradTexMissing = true end
    end
    return gradTex
end

function Draw.sheen(el, x, y, w, h, a, c)
    local g = gradTexture()
    if g == nil then return end
    el:drawTextureScaled(g, x, y, w, h, a, c.r, c.g, c.b)
end

function Draw.headerLine(el, x, y, w, sheenH, colors)
    local sf = colors and colors.SURFACE
    if sf == nil then return end
    if sheenH and sheenH > 0 then
        Draw.sheen(el, x, y - sheenH, w, sheenH, 0.06, sf.accent)
    end
    el:drawRect(x, y, w, 1, 0.8, sf.line.r, sf.line.g, sf.line.b)
end

local dotTex = nil
local dotTexMissing = false
local function dotTexture()
    if dotTex == nil and not dotTexMissing then
        dotTex = TextureCache.get("media/textures/comfy_dot.png")
        if dotTex == nil then dotTexMissing = true end
    end
    return dotTex
end

function Draw.disc(el, x, y, d, a, c)
    local t = dotTexture()
    if t ~= nil then
        el:drawTextureScaled(t, x, y, d, d, a, c.r, c.g, c.b)
    else
        Draw.roundRect(el, x, y, d, d, floor(d * 0.5), a, c)
    end
end

function Draw.pie(el, cx, cy, r, sweep, a, c)
    if r < 1 or sweep <= 0 then return end
    if sweep >= 6.2831853 then
        Draw.disc(el, floor(cx - r), floor(cy - r), floor(r * 2), a, c)
        return
    end
    local wide = sweep > 3.1415927
    local d1x, d1y = sin(sweep), -cos(sweep)
    local ri = floor(r)
    for dy = -ri, ri do
        local half = sqrt(r * r - dy * dy)
        local x0 = -floor(half)
        local x1 = floor(half)
        local runStart = nil
        for dx = x0, x1 + 1 do
            local inside = false
            if dx <= x1 then
                local c1 = d1x * dy - d1y * dx
                if wide then
                    inside = dx >= 0 or c1 <= 0
                else
                    inside = dx >= 0 and c1 <= 0
                end
            end
            if inside and runStart == nil then
                runStart = dx
            elseif not inside and runStart ~= nil then
                el:drawRect(floor(cx + runStart), floor(cy + dy),
                    dx - runStart, 1, a, c.r, c.g, c.b)
                runStart = nil
            end
        end
    end
end

local glyphTex = {}
local glyphMissing = {}

function Draw.glyphTexture(id)
    if id == nil or glyphMissing[id] then return nil end
    local t = glyphTex[id]
    if t == nil then
        t = TextureCache.get("media/textures/comfy_" .. id .. ".png")
        if t == nil then
            glyphMissing[id] = true
            return nil
        end
        glyphTex[id] = t
    end
    return t
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

    local S = ComfyGrid.UI and ComfyGrid.UI.Style

    local T = ComfyGrid.UI and ComfyGrid.UI.Themes
    local fallback = (T ~= nil and T.DEFAULT) or "amber"
    local theme = (S ~= nil and S.THEME) or fallback
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
    local ms = UIManager.getMillisSinceLastRender()
    local d = ms / 33.3
    if d > 3 then d = 3 end
    return d
end

function Draw.glide(cur, target, rate)
    local k = rate * Draw.delta()
    if k > 1 then k = 1 end
    local nxt = cur + (target - cur) * k
    local diff = nxt - target
    if diff < 0.002 and diff > -0.002 then return target end
    return nxt
end
