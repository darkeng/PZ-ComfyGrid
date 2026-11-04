--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.11
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local RangeSelect = {}
ComfyGrid.Interact.RangeSelect = RangeSelect

local owner = nil

function RangeSelect.drop(surface)
    surface.rangeAnchorSlot = nil
    surface.markHoldAnchored = false
    if owner == surface then owner = nil end
end

function RangeSelect.dropAny()
    if owner ~= nil then RangeSelect.drop(owner) end
end

function RangeSelect.setAnchor(surface, index, inHold)
    if owner ~= nil and owner ~= surface then RangeSelect.drop(owner) end
    owner = surface
    surface.rangeAnchorSlot = index
    surface.markHoldAnchored = inHold == true
end

function RangeSelect.pressOn(surface)
    surface.pressReceived = true
    if owner ~= nil and owner ~= surface then RangeSelect.drop(owner) end
end

function RangeSelect.markClick(surface, index, toggle, addRange)
    if index == nil then return end
    if surface.markHoldAnchored then
        addRange(surface, surface.rangeAnchorSlot, index)
        return
    end
    toggle(surface)
    if ComfyGrid.Settings.markRangeOn() then
        RangeSelect.setAnchor(surface, index, true)
    end
end

function RangeSelect.rangeClick(surface, index, replaceRange, markAlone)
    if surface.rangeAnchorSlot ~= nil then
        replaceRange(surface, surface.rangeAnchorSlot, index)
    else
        markAlone(surface, index)
        RangeSelect.setAnchor(surface, index, false)
    end
end

function RangeSelect.tick(surface)
    if surface.rangeAnchorSlot == nil then return end
    if surface.markHoldAnchored and not ComfyGrid.Settings.multiSelectHeld() then
        surface.markHoldAnchored = false
    end
    if not (isMouseButtonDown(0) or isMouseButtonDown(1)) then
        surface.pressReceived = false
    elseif not surface.pressReceived then
        RangeSelect.drop(surface)
    end
end

function RangeSelect.nextClickRanges(surface)
    if surface.rangeAnchorSlot == nil then return false end
    return surface.markHoldAnchored or ComfyGrid.Settings.rangeSelectHeld()
end

return RangeSelect
