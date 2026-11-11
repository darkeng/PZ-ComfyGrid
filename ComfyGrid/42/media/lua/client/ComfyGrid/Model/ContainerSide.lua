--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.10.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"

ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local ContainerSide = {}
ComfyGrid.Model.ContainerSide = ContainerSide

function ContainerSide.isCarried(container, playerObj)
    if container == nil or playerObj == nil then return false end
    if container == playerObj:getInventory() then return true end
    local ok, inside = pcall(container.isInCharacterInventory, container, playerObj)
    return ok and inside == true
end

return ContainerSide
