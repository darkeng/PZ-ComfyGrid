--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.3
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local ServerAddress = {}
ComfyGrid.Model.ServerAddress = ServerAddress

ServerAddress.OPEN = "open"
ServerAddress.RELAY = "relay"
ServerAddress.REFUSE = "refuse"

local MAX_NESTING = 16

local function holderOf(item)
    local ok, holder = pcall(item.getContainer, item)
    if ok then return holder end
    return nil
end

local function bagOwning(container)
    local ok, bag = pcall(container.getContainingItem, container)
    if ok then return bag end
    return nil
end

local function endsInPlayerInventory(container)
    local current = container
    for _ = 1, MAX_NESTING do
        local bag = bagOwning(current)
        if bag == nil then
            local ok, parent = pcall(current.getParent, current)
            return ok and parent ~= nil and instanceof(parent, "IsoPlayer")
        end
        current = holderOf(bag)

        if current == nil then return false end
    end
    return false
end

function ServerAddress.verdictFor(bagItem, inMultiplayer)
    if not inMultiplayer or bagItem == nil then return ServerAddress.OPEN end
    local holder = holderOf(bagItem)
    if holder == nil then return ServerAddress.OPEN end
    if endsInPlayerInventory(holder) then return ServerAddress.OPEN end
    if bagOwning(holder) ~= nil then return ServerAddress.REFUSE end
    local okPart, part = pcall(holder.getVehiclePart, holder)
    if okPart and part ~= nil then return ServerAddress.OPEN end
    local okParent, parent = pcall(holder.getParent, holder)
    if not okParent or parent == nil then return ServerAddress.OPEN end

    if instanceof(parent, "IsoDeadBody") then return ServerAddress.RELAY, holder end
    if instanceof(parent, "IsoGameCharacter") or instanceof(parent, "BaseVehicle") then
        return ServerAddress.OPEN
    end
    if instanceof(parent, "IsoObject") then return ServerAddress.RELAY, holder end
    return ServerAddress.OPEN
end

function ServerAddress.verdictNow(bagItem)
    return ServerAddress.verdictFor(bagItem, isClient())
end
