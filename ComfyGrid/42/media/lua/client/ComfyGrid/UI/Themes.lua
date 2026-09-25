--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.9
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/UI/Style"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local Themes = {}
ComfyGrid.UI.Themes = Themes

local Style = ComfyGrid.UI.Style

Themes.ORDER = { "amber", "dark", "slate", "olive", "sakura" }

Themes.DEFAULT = "amber"

Themes.byName = {}

Themes.byName.amber = {
    surface = {
        dark   = { r = 0.055, g = 0.050, b = 0.042 },
        bg     = { r = 0.082, g = 0.074, b = 0.062 },
        panel  = { r = 0.110, g = 0.100, b = 0.085 },
        card   = { r = 0.148, g = 0.135, b = 0.116 },
        cardHi = { r = 0.246, g = 0.225, b = 0.194 },
        line   = { r = 0.44,  g = 0.39,  b = 0.29 },
        accent = { r = 0.85,  g = 0.74,  b = 0.51 },
    },
    countText   = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
    countShadow = { r = 0.0, g = 0.0, b = 0.0, a = 1.0 },
    categorySaturation = 1.0,
    categoryBrightness = 1.0,
}

Themes.byName.dark = {
    surface = {
        dark   = { r = 0.000, g = 0.000, b = 0.000 },
        bg     = { r = 0.000, g = 0.000, b = 0.000 },
        panel  = { r = 0.070, g = 0.070, b = 0.070 },
        card   = { r = 0.145, g = 0.145, b = 0.145 },
        cardHi = { r = 0.300, g = 0.300, b = 0.300 },
        line   = { r = 0.400, g = 0.400, b = 0.400 },
        accent = { r = 0.800, g = 0.800, b = 0.800 },
    },
    countText   = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
    countShadow = { r = 0.0, g = 0.0, b = 0.0, a = 1.0 },
    categorySaturation = 0.85,
    categoryBrightness = 1.0,
}

Themes.byName.slate = {
    surface = {
        dark   = { r = 0.030, g = 0.038, b = 0.055 },
        bg     = { r = 0.048, g = 0.060, b = 0.086 },
        panel  = { r = 0.070, g = 0.088, b = 0.125 },
        card   = { r = 0.100, g = 0.126, b = 0.180 },
        cardHi = { r = 0.172, g = 0.211, b = 0.293 },
        line   = { r = 0.30,  g = 0.40,  b = 0.58 },
        accent = { r = 0.62,  g = 0.76,  b = 0.95 },
    },
    countText   = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
    countShadow = { r = 0.0, g = 0.0, b = 0.0, a = 1.0 },
    categorySaturation = 0.80,
    categoryBrightness = 1.0,
}

Themes.byName.olive = {
    surface = {
        dark   = { r = 0.036, g = 0.042, b = 0.026 },
        bg     = { r = 0.056, g = 0.066, b = 0.038 },
        panel  = { r = 0.082, g = 0.098, b = 0.056 },
        card   = { r = 0.116, g = 0.138, b = 0.078 },
        cardHi = { r = 0.186, g = 0.223, b = 0.127 },
        line   = { r = 0.40,  g = 0.47,  b = 0.24 },
        accent = { r = 0.76,  g = 0.85,  b = 0.48 },
    },
    countText   = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
    countShadow = { r = 0.0, g = 0.0, b = 0.0, a = 1.0 },
    categorySaturation = 0.80,
    categoryBrightness = 1.0,
}

Themes.byName.sakura = {
    surface = {
        dark   = { r = 0.060, g = 0.034, b = 0.044 },
        bg     = { r = 0.092, g = 0.052, b = 0.066 },
        panel  = { r = 0.130, g = 0.074, b = 0.094 },
        card   = { r = 0.180, g = 0.104, b = 0.130 },
        cardHi = { r = 0.293, g = 0.171, b = 0.212 },
        line   = { r = 0.62,  g = 0.34,  b = 0.44 },
        accent = { r = 0.96,  g = 0.66,  b = 0.76 },
    },
    countText   = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
    countShadow = { r = 0.0, g = 0.0, b = 0.0, a = 1.0 },
    categorySaturation = 0.80,
    categoryBrightness = 1.0,
}

function Themes.get(name)
    return Themes.byName[name] or Themes.byName[Themes.DEFAULT]
end

function Themes.exists(name)
    return Themes.byName[name] ~= nil
end

function Themes.apply(name)
    if not Themes.exists(name) then
        name = Themes.DEFAULT
    end
    Style.applyPalette(name, Themes.get(name))
    return name
end

return Themes
