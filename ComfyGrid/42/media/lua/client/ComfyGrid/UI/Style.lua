--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.9
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Util"
require "ComfyGrid/Settings"
require "ComfyGrid/Model/Categories"

ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local Style = {}
ComfyGrid.UI.Style = Style

local Log = ComfyGrid.Core.Log
local Util = ComfyGrid.Core.Util
local Settings = ComfyGrid.Settings

local floor = math.floor

local MIN_SCALE = 0.3
local MAX_SCALE = 4

local MAX_EFFECTIVE = 8

Style.SCALE = 1
Style.USER_SCALE = 1
Style.FONT_SCALE = 1
Style.TEXTURE_SIZE = 40
Style.PAD = 2
Style.CELL = 45
Style.CELL_STRIDE = 44

Style.BAR_INSET = 7

Style.FONT_H = 16
Style.SMALL_H = 16

local scaleListeners = {}

function Style.onScaleChanged(fn)
    scaleListeners[#scaleListeners + 1] = fn
end

local pickFont

local function recompute(force)
    local eff = Util.clamp(Style.USER_SCALE * Style.FONT_SCALE,
        MIN_SCALE, MAX_EFFECTIVE)
    local oldScale = Style.SCALE
    local textureSize = floor(40 * eff)
    local pad = floor(2 * eff)
    local cell = textureSize + 2 * pad + 1

    if not force and eff == oldScale and cell == Style.CELL then
        return
    end
    Style.SCALE = eff
    Style.TEXTURE_SIZE = textureSize
    Style.PAD = pad
    Style.CELL = cell
    Style.CELL_STRIDE = cell - 1

    local barInset = floor(cell * 0.14)
    if barInset > 7 then barInset = 7 elseif barInset < 4 then barInset = 4 end
    Style.BAR_INSET = barInset
    for i = 1, #scaleListeners do

        local ok, err = pcall(scaleListeners[i], eff, oldScale)
        if not ok then
            Log.warn("Style scale listener failed: " .. tostring(err))
        end
    end
end

function Style.applyScale(s)
    if type(s) ~= "number" then
        s = Settings.defaults.SCALE
    end
    Style.USER_SCALE = Util.clamp(s, MIN_SCALE, MAX_SCALE)

    recompute(pickFont())
end

local SMALLEST_FONT_H = 16

local ladderCache = nil
local function ladder()
    if ladderCache == nil and UIFont ~= nil then
        ladderCache = { UIFont.Small, UIFont.Medium, UIFont.Large }
    end
    return ladderCache
end

local function rungFor(eff)
    if eff >= 1.9 then return 3 end
    if eff >= 1.5 then return 2 end
    return 1
end

function pickFont()
    if UIFont == nil then return false end
    local tm = type(getTextManager) == "function" and getTextManager() or nil
    if tm == nil then return false end
    local eff = Util.clamp(Style.USER_SCALE * Style.FONT_SCALE,
        MIN_SCALE, MAX_EFFECTIVE)
    local rungs = ladder()
    local font = rungs ~= nil and rungs[rungFor(eff)] or UIFont.Small
    local changed = false
    if font ~= nil and font ~= Style.FONT then
        Style.FONT = font
        changed = true
    end
    local h = tm:getFontHeight(Style.FONT)
    if type(h) == "number" and h > 0 and h ~= Style.FONT_H then
        Style.FONT_H = h
        changed = true
    end
    return changed
end

function Style.refreshFont()
    if UIFont == nil then return end
    local changed = false
    local tm = type(getTextManager) == "function" and getTextManager() or nil
    if tm ~= nil then

        local small = tm:getFontHeight(UIFont.Small)
        if type(small) == "number" and small > 0 and small ~= Style.SMALL_H then
            Style.SMALL_H = small
            changed = true
        end

        local fs = Style.SMALL_H / SMALLEST_FONT_H
        if fs > 0 and fs ~= Style.FONT_SCALE then
            Style.FONT_SCALE = fs
            changed = true
        end
        if pickFont() then changed = true end
    end
    if changed then
        recompute(true)
    end
end

function Style.gridPixelSize(cols, rows)
    local stride = Style.CELL_STRIDE
    return cols * stride + 1, rows * stride + 1
end

function Style.slotAtPixel(localX, localY, cols, rows)
    if localX < 0 or localY < 0 then
        return nil
    end
    local stride = Style.CELL_STRIDE
    local col = floor(localX / stride)
    local row = floor(localY / stride)
    if col >= cols or row >= rows then
        return nil
    end
    return row * cols + col
end

function Style.pixelForSlot(slot, cols)
    local stride = Style.CELL_STRIDE
    local col = slot % cols

    local row = floor(slot / cols)
    return col * stride, row * stride
end

Style.COLORS = {

    SURFACE = {
        dark   = { r = 0.055, g = 0.050, b = 0.042 },
        bg     = { r = 0.082, g = 0.074, b = 0.062 },
        panel  = { r = 0.110, g = 0.100, b = 0.085 },
        card   = { r = 0.148, g = 0.135, b = 0.116 },
        cardHi = { r = 0.246, g = 0.225, b = 0.194 },
        line   = { r = 0.44,  g = 0.39,  b = 0.29 },
        accent = { r = 0.85,  g = 0.74,  b = 0.51 },
    },

    BOARD_BG   = { r = 0.082, g = 0.074, b = 0.062, a = 0.95 },
    GRID_LINES = { r = 0.30, g = 0.30, b = 0.33, a = 1.0 },
    EMPTY_CELL = { r = 0.148, g = 0.135, b = 0.116, a = 1.0 },
    HOVER      = { r = 1.0,  g = 1.0,  b = 1.0,  a = 0.12 },

    COUNT_TEXT   = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
    COUNT_SHADOW = { r = 0.0, g = 0.0, b = 0.0, a = 1.0 },

    BAR_BG   = { r = 0.0,  g = 0.0,  b = 0.0,  a = 0.5 },
    BAR_LOW  = { r = 0.80, g = 0.18, b = 0.12, a = 1.0 },
    BAR_MID  = { r = 0.85, g = 0.75, b = 0.10, a = 1.0 },
    BAR_HIGH = { r = 0.20, g = 0.80, b = 0.75, a = 1.0 },

    BOOK_LOCKED = { r = 0.72, g = 0.42, b = 0.36, a = 1.0 },

    READ_TICK       = { r = 0.36, g = 0.88, b = 0.52, a = 1.0 },
    READ_TICK_LINE  = { r = 0.05, g = 0.12, b = 0.07, a = 1.0 },
    FAVORITE        = { r = 0.98, g = 0.78, b = 0.25, a = 1.0 },
    FAVORITE_LINE   = { r = 0.12, g = 0.09, b = 0.02, a = 1.0 },

    BROKEN      = { r = 0.92, g = 0.16, b = 0.13, a = 0.82 },
    BROKEN_LINE = { r = 0.10, g = 0.05, b = 0.05, a = 0.74 },

    WEIGHT_LOW  = { r = 0.45, g = 0.80, b = 0.40, a = 1.0 },
    WEIGHT_MID  = { r = 0.93, g = 0.56, b = 0.20, a = 1.0 },
    WEIGHT_DEEP = { r = 0.64, g = 0.10, b = 0.09, a = 1.0 },
    WEIGHT_HIGH = { r = 1.00, g = 0.17, b = 0.12, a = 1.0 },

    DROP_OK  = { r = 0.20, g = 0.75, b = 0.25, a = 0.35 },
    DROP_BAD = { r = 0.80, g = 0.15, b = 0.15, a = 0.35 },

    TRANSFER_OVERLAY = { r = 0.0, g = 0.0, b = 0.0, a = 0.72 },
    TRANSFER_EDGE    = { r = 0.95, g = 0.80, b = 0.25, a = 0.90 },

    SELECTED = { r = 0.35, g = 0.75, b = 1.0, a = 0.90 },

    APPLY = { r = 0.42, g = 0.92, b = 0.50, a = 0.90 },
}

Style.COLORS.CATEGORY = {
    Food       = { r = 0.10, g = 0.22, b = 0.10, a = 1.0 },
    Weapon     = { r = 0.26, g = 0.10, b = 0.10, a = 1.0 },
    Clothing   = { r = 0.18, g = 0.12, b = 0.22, a = 1.0 },
    Container  = { r = 0.22, g = 0.18, b = 0.10, a = 1.0 },
    Ammo       = { r = 0.24, g = 0.22, b = 0.08, a = 1.0 },
    Literature = { r = 0.10, g = 0.14, b = 0.26, a = 1.0 },
    Medical    = { r = 0.08, g = 0.22, b = 0.22, a = 1.0 },
    default    = { r = 0.16, g = 0.16, b = 0.17, a = 1.0 },
}

Style.COLORS.CATEGORY.FirstAid = Style.COLORS.CATEGORY.Medical
Style.COLORS.CATEGORY.Bag = Style.COLORS.CATEGORY.Container

local BUCKET_TINT = {
    weapons    = Style.COLORS.CATEGORY.Weapon,
    tools      = { r = 0.15, g = 0.15, b = 0.17, a = 1.0 },
    food       = Style.COLORS.CATEGORY.Food,
    medical    = Style.COLORS.CATEGORY.Medical,
    hygiene    = { r = 0.20, g = 0.22, b = 0.28, a = 1.0 },
    kitchen    = { r = 0.24, g = 0.16, b = 0.08, a = 1.0 },
    materials  = { r = 0.17, g = 0.13, b = 0.07, a = 1.0 },
    containers = Style.COLORS.CATEGORY.Container,
    literature = Style.COLORS.CATEGORY.Literature,
    clothing   = Style.COLORS.CATEGORY.Clothing,
    survival   = { r = 0.15, g = 0.17, b = 0.11, a = 1.0 },
    misc       = { r = 0.17, g = 0.16, b = 0.15, a = 1.0 },
    other      = Style.COLORS.CATEGORY.default,
}
Style.COLORS.BUCKET = BUCKET_TINT
do

    local Categories = ComfyGrid.Model and ComfyGrid.Model.Categories
    if Categories ~= nil and Categories.BUCKET ~= nil then
        local cats = Style.COLORS.CATEGORY
        for cat, bucket in pairs(Categories.BUCKET) do
            if cats[cat] == nil then
                cats[cat] = BUCKET_TINT[bucket] or cats.default
            end
        end
    end
end

local catTint = {}
local BAND_TINTS = {
    BUCKET_TINT.tools, BUCKET_TINT.materials, BUCKET_TINT.survival,
    BUCKET_TINT.hygiene, BUCKET_TINT.kitchen, BUCKET_TINT.misc,
    BUCKET_TINT.literature, BUCKET_TINT.containers,
}

function Style.tintForCategory(cat)
    if cat == nil then return Style.COLORS.CATEGORY.default end
    local memo = catTint[cat]
    if memo ~= nil then return memo end

    local tint = Style.COLORS.CATEGORY[cat]
    if tint == nil then
        local Categories = ComfyGrid.Model and ComfyGrid.Model.Categories
        local bucket = nil
        if Categories ~= nil and Categories.bucketForCategory ~= nil then
            bucket = Categories.bucketForCategory(cat)
        end
        if bucket ~= nil then
            tint = BUCKET_TINT[bucket]
        else

            local h = 0
            for i = 1, #cat do h = h + string.byte(cat, i) end
            tint = BAND_TINTS[(h % #BAND_TINTS) + 1]
        end
    end
    tint = tint or Style.COLORS.CATEGORY.default
    catTint[cat] = tint
    return tint
end

Style.THEME = "amber"

local paletteListeners = {}

function Style.onPaletteChanged(fn)
    paletteListeners[#paletteListeners + 1] = fn
end

local function writeColor(dst, src)
    if dst == nil or src == nil then return end
    dst.r, dst.g, dst.b = src.r, src.g, src.b
    if src.a ~= nil then dst.a = src.a end
end

local baseCategory = {}

do
    local function snapshot(t)
        if t == nil then return end
        for _, c in pairs(t) do
            if type(c) == "table" and c.r ~= nil and baseCategory[c] == nil then
                baseCategory[c] = { r = c.r, g = c.g, b = c.b }
            end
        end
    end
    snapshot(Style.COLORS.CATEGORY)
    snapshot(Style.COLORS.BUCKET)
end

local function recolorCategories(sat, bri)
    sat = sat or 1
    bri = bri or 1
    for live, base in pairs(baseCategory) do
        local l = 0.299 * base.r + 0.587 * base.g + 0.114 * base.b
        local r = (l + (base.r - l) * sat) * bri
        local g = (l + (base.g - l) * sat) * bri
        local b = (l + (base.b - l) * sat) * bri
        live.r = r < 0 and 0 or (r > 1 and 1 or r)
        live.g = g < 0 and 0 or (g > 1 and 1 or g)
        live.b = b < 0 and 0 or (b > 1 and 1 or b)
    end
end

local LADDER = { "dark", "bg", "panel", "card", "cardHi", "line", "accent" }

function Style.applyPalette(name, theme)
    if type(theme) ~= "table" then return end
    local C = Style.COLORS
    local sf = C.SURFACE
    if type(theme.surface) == "table" then
        for i = 1, #LADDER do
            writeColor(sf[LADDER[i]], theme.surface[LADDER[i]])
        end
    end

    writeColor(C.BOARD_BG, theme.board or sf.bg)
    writeColor(C.EMPTY_CELL, theme.emptyCell or sf.card)
    writeColor(C.COUNT_TEXT, theme.countText)
    writeColor(C.COUNT_SHADOW, theme.countShadow)
    recolorCategories(theme.categorySaturation, theme.categoryBrightness)
    Style.THEME = name or Style.THEME
    for i = 1, #paletteListeners do

        local ok, err = pcall(paletteListeners[i], Style.THEME)
        if not ok then
            Log.warn("Style palette listener failed: " .. tostring(err))
        end
    end
end

function Style.headerHeight()
    return math.max(18, Style.FONT_H + 4, floor(Style.CELL / 2))
end

Style.FONT = UIFont and UIFont.Small or nil

Style.applyScale(Settings.get("SCALE"))

Settings.onChanged("SCALE", function(newValue)
    Style.applyScale(newValue)
end)

if Events ~= nil and Events.OnRenderTick ~= nil
        and not ComfyGrid._styleFontTickHooked then
    ComfyGrid._styleFontTickHooked = true
    Events.OnRenderTick.Add(function()
        local S = ComfyGrid.UI ~= nil and ComfyGrid.UI.Style or nil
        if S ~= nil and S.refreshFont ~= nil then
            S.refreshFont()
        end
    end)
end
