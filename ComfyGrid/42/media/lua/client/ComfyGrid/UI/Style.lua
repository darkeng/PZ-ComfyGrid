--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.3.4
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Util"
require "ComfyGrid/Settings"

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

Style.FONT_H = 16

local scaleListeners = {}

function Style.onScaleChanged(fn)
    scaleListeners[#scaleListeners + 1] = fn
end

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
    recompute(false)
end

function Style.refreshFont()
    if UIFont == nil then return end
    local changed = false
    local core = type(getCore) == "function" and getCore() or nil
    if core ~= nil and core.getOptionFontSizeReal ~= nil then
        local real = core:getOptionFontSizeReal()
        if type(real) == "number" and real > 0
                and real ~= Style.FONT_SCALE then
            Style.FONT_SCALE = real
            changed = true
        end
    end
    local tm = type(getTextManager) == "function" and getTextManager() or nil
    if tm ~= nil then
        local h = tm:getFontHeight(UIFont.Small)
        if type(h) == "number" and h > 0 and h ~= Style.FONT_H then
            Style.FONT_H = h
            changed = true
        end
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
        cardHi = { r = 0.190, g = 0.174, b = 0.150 },
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
