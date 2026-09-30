--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.1
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local ContainerName = {}
ComfyGrid.Model.ContainerName = ContainerName

function ContainerName.titleForType(invType)
    if invType == nil then return nil end
    return getTextOrNull("IGUI_ContainerTitle_" .. invType)
        or getTextOrNull("IGUI_VehiclePart" .. invType)
        or invType
end

local function isVehiclePart(inv)
    if inv.getVehiclePart == nil then return false end
    local ok, part = pcall(inv.getVehiclePart, inv)
    return ok and part ~= nil
end

local function displayTypeOf(inv, invType)
    if inv.getDisplayType == nil then return nil end
    local ok, display = pcall(inv.getDisplayType, inv)
    if not ok or display == nil then return nil end
    display = tostring(display)
    if display == invType then return nil end
    return display
end

function ContainerName.titleFor(inv)
    if inv == nil then return nil end
    local okT, invType = pcall(inv.getType, inv)
    if not okT or invType == nil then return nil end
    invType = tostring(invType)
    if isVehiclePart(inv) then
        local part = getTextOrNull("IGUI_VehiclePart" .. invType)
        if part ~= nil then return part end
    end
    local title = getTextOrNull("IGUI_ContainerTitle_" .. invType)
    if title ~= nil then return title end
    local display = displayTypeOf(inv, invType)
    if display ~= nil then
        title = getTextOrNull("IGUI_ContainerTitle_" .. display)
        if title ~= nil then return title end
    end
    return ContainerName.titleForType(invType)
end
