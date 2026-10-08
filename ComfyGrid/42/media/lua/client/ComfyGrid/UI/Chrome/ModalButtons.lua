--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Draw"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
ComfyGrid.UI.Chrome = ComfyGrid.UI.Chrome or {}

local Style = ComfyGrid.UI.Style
local Draw = ComfyGrid.UI.Draw

local ModalButtons = {}
ComfyGrid.UI.Chrome.ModalButtons = ModalButtons

local SHADOW_SPREAD = 16
local SHADOW_ALPHA = 0.55
local SHELL_RADIUS = 6
local SHELL_ALPHA = 0.98

function ModalButtons.measure(text)
    if text == nil or text == "" then return 0 end
    local textManager = getTextManager ~= nil and getTextManager() or nil
    if textManager == nil then return 0 end
    local ok, width = pcall(textManager.MeasureStringX, textManager, Style.FONT,
        text)
    if ok then return width end
    return 0
end

function ModalButtons.drawShell(panel)
    local surface = Style.COLORS.SURFACE
    Draw.shadow(panel, 0, 0, panel.width, panel.height, SHADOW_SPREAD,
        SHADOW_ALPHA)
    Draw.roundFrame(panel, 0, 0, panel.width, panel.height, SHELL_RADIUS,
        SHELL_ALPHA, surface.line, surface.bg, SHELL_ALPHA)
end

function ModalButtons.buttonAt(buttons, x, y)
    if buttons == nil then return nil end
    for i = 1, #buttons do
        local button = buttons[i]
        if x >= button.x and x < button.x + button.w
                and y >= button.y and y < button.y + button.h then
            return button
        end
    end
    return nil
end

function ModalButtons.drawButtons(panel, buttons, radius)
    if buttons == nil then return end
    local surface = Style.COLORS.SURFACE
    local accent = surface.accent
    local fontHeight = Style.FONT_H
    local hotButton = nil
    if panel:isMouseOver() then
        hotButton = ModalButtons.buttonAt(buttons, panel:getMouseX(),
            panel:getMouseY())
    end
    for i = 1, #buttons do
        local button = buttons[i]
        local hot = button == hotButton
        Draw.roundFrame(panel, button.x, button.y, button.w, button.h, radius,
            1, hot and accent or surface.line,
            hot and surface.cardHi or surface.card, 1)
        local labelY = button.y + math.floor((button.h - fontHeight) / 2)
        local labelAlpha = hot and 1 or 0.85
        if button.labelWidth ~= nil then
            panel:drawText(button.label,
                button.x + math.floor((button.w - button.labelWidth) / 2),
                labelY, accent.r, accent.g, accent.b, labelAlpha, Style.FONT)
        else
            panel:drawTextCentre(button.label, button.x + button.w / 2,
                labelY, accent.r, accent.g, accent.b, labelAlpha, Style.FONT)
        end
    end
end

return ModalButtons
