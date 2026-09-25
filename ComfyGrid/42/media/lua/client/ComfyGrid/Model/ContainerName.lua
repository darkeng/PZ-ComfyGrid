--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.9
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
