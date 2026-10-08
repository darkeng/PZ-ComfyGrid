--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local ContainerName = {}
ComfyGrid.Model.ContainerName = ContainerName

local renameGen = 0

function ContainerName.renameGeneration()
    return renameGen
end

function ContainerName.invalidateNames()
    renameGen = renameGen + 1
end

if not ComfyGrid._containerNamesHooked then
    ComfyGrid._containerNamesHooked = true
    Events.OnRefreshInventoryWindowContainers.Add(function(_page, stage)
        if stage ~= "end" then return end
        local Names = ComfyGrid.Model and ComfyGrid.Model.ContainerName
        if Names ~= nil and Names.invalidateNames ~= nil then
            Names.invalidateNames()
        end
    end)
end

function ContainerName.titleForType(invType)
    if invType == nil then return nil end
    return getTextOrNull("IGUI_ContainerTitle_" .. invType)
        or getTextOrNull("IGUI_VehiclePart" .. invType)
        or invType
end

local function isVehiclePart(inv)
    if inv.getVehiclePart == nil then return false end
    local ok, vehiclePart = pcall(inv.getVehiclePart, inv)
    return ok and vehiclePart ~= nil
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
    local okType, invType = pcall(inv.getType, inv)
    if not okType or invType == nil then return nil end
    invType = tostring(invType)
    if isVehiclePart(inv) then
        local partTitle = getTextOrNull("IGUI_VehiclePart" .. invType)
        if partTitle ~= nil then return partTitle end
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
