--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.7.3
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
ComfyGrid.UI.Chrome = ComfyGrid.UI.Chrome or {}
local HoverTip = {}
ComfyGrid.UI.Chrome.HoverTip = HoverTip

local tipUI = nil
local claimant = nil

local CURSOR_DX = 23
local CURSOR_DY = 23

function HoverTip.show(claim, owner, text, x, y)
    if claim == nil or text == nil or text == "" then return false end
    if owner == nil or owner.getAbsoluteX == nil then return false end
    if tipUI == nil then
        if ISToolTip == nil then return false end
        tipUI = ISToolTip:new()
        tipUI:setVisible(false)
        tipUI:setAlwaysOnTop(true)
    end

    tipUI:setOwner(owner)
    tipUI.maxLineWidth = 300
    tipUI.description = text
    if not tipUI:getIsVisible() then
        tipUI:addToUIManager()
        tipUI:setVisible(true)
    end
    if x == nil or y == nil then
        x = (getMouseX and getMouseX() or 0) + CURSOR_DX
        y = (getMouseY and getMouseY() or 0) + CURSOR_DY
    end

    local core = getCore and getCore() or nil
    if core ~= nil and tipUI.width ~= nil and tipUI.width > 0 then
        local sw, sh = core:getScreenWidth(), core:getScreenHeight()
        if x + tipUI.width > sw then x = sw - tipUI.width end
        if y + tipUI.height > sh then y = sh - tipUI.height end
        if x < 0 then x = 0 end
        if y < 0 then y = 0 end
    end
    tipUI:setDesiredPosition(x, y)
    claimant = claim
    return true
end

function HoverTip.hide(claim)
    if claimant ~= claim or tipUI == nil then return end
    claimant = nil
    if tipUI:getIsVisible() then
        tipUI:setVisible(false)
        tipUI:removeFromUIManager()
    end
end
