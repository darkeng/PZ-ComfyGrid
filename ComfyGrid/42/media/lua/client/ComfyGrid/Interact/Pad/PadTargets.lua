--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.10.1
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/UI/Style"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local PadTargets = {}
ComfyGrid.Interact.PadTargets = PadTargets

local Style = ComfyGrid.UI.Style

function PadTargets.cellRect(node, slot, out, elX, elY)
    local el = node.el
    local left, top, width, height
    if node.kind == "chip" then
        if el.padChipRect == nil then return false end
        left, top, width, height = el:padChipRect(slot)
        if left == nil then return false end
    else
        if el.padTileXY ~= nil then
            left, top = el:padTileXY(slot)
        else
            left, top = Style.pixelForSlot(slot, el.cols or 1)
        end
        width, height = Style.CELL, Style.CELL
    end
    local x = (elX or el:getAbsoluteX()) + left
    local y = (elY or el:getAbsoluteY()) + top
    out.x0, out.y0, out.x1, out.y1 = x, y, x + width, y + height
    return true
end

local function coverOf(window)
    local x, y = window:getAbsoluteX(), window:getAbsoluteY()
    return { window = window, x0 = x, y0 = y,
        x1 = x + window:getWidth(), y1 = y + window:getHeight() }
end

function PadTargets.covers(playerNum)
    local covers = {}
    local ContainerWindow = ComfyGrid.UI and ComfyGrid.UI.ContainerWindow
    local bagWindow = ContainerWindow ~= nil and ContainerWindow.windowFor ~= nil
        and ContainerWindow.windowFor(playerNum) or nil
    if bagWindow ~= nil and bagWindow:getIsVisible() then
        covers[#covers + 1] = coverOf(bagWindow)
    end
    local EquipWindow = ComfyGrid.UI and ComfyGrid.UI.EquipWindow
    local equipWindow = EquipWindow ~= nil and EquipWindow.windowFor ~= nil
        and EquipWindow.windowFor(playerNum) or nil
    if equipWindow ~= nil and equipWindow:getIsVisible() then
        covers[#covers + 1] = coverOf(equipWindow)
    end
    return covers
end

function PadTargets.isCovered(rect, covers, ownWindow, onScreen)
    if not onScreen then return false end
    local centreX = (rect.x0 + rect.x1) / 2
    local centreY = (rect.y0 + rect.y1) / 2
    for i = 1, #covers do
        local cover = covers[i]
        if cover.window ~= ownWindow
                and centreX >= cover.x0 and centreX < cover.x1
                and centreY >= cover.y0 and centreY < cover.y1 then
            return true
        end
    end
    return false
end

return PadTargets
