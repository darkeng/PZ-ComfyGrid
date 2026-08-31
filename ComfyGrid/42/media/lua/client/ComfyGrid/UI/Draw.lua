--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.5.0
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

function Draw.floorTexture()
    return Draw.glyphTexture("floor")
end

function Draw.moreTexture()
    return Draw.glyphTexture("more")
end

local titlebarTex = nil
local titlebarTexMissing = false

function Draw.titlebarTexture()
    if titlebarTex == nil and not titlebarTexMissing then
        titlebarTex = TextureCache.get("media/textures/comfy_titlebar.png")
        if titlebarTex == nil then titlebarTexMissing = true end
    end
    return titlebarTex
end

function Draw.pinTexture()
    return Draw.glyphTexture("pin")
end

local gripTex = nil
local gripTexMissing = false

function Draw.gripTexture()
    if gripTex == nil and not gripTexMissing then
        gripTex = TextureCache.get("media/textures/comfy_grip.png")
        if gripTex == nil then gripTexMissing = true end
    end
    return gripTex
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
