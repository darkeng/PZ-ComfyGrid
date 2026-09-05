--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.5.3
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local Persistence = {}
ComfyGrid.Model.Persistence = Persistence

local memoryModData = {}
local memoryAccessMs = {}
local memoryCount = 0
local MAX_MEMORY_ENTRIES = 64

local function evictOldestMemory()
    local oldestKey, oldestMs
    for inventory, ms in pairs(memoryAccessMs) do
        if oldestMs == nil or ms < oldestMs then
            oldestKey, oldestMs = inventory, ms
        end
    end
    if oldestKey ~= nil then
        memoryModData[oldestKey] = nil
        memoryAccessMs[oldestKey] = nil
        memoryCount = memoryCount - 1
    end
end

local function memoryFor(inventory)
    local md = memoryModData[inventory]
    if md == nil then
        if memoryCount >= MAX_MEMORY_ENTRIES then
            evictOldestMemory()
        end
        md = {}
        memoryModData[inventory] = md
        memoryCount = memoryCount + 1
    end
    memoryAccessMs[inventory] = getTimestampMs()
    return md
end

local function mergeBucket(kind, owner)
    if owner == nil or not isClient() then return end
    local ComfyClient = ComfyGrid.Networking and ComfyGrid.Networking.ComfyClient
    if ComfyClient == nil then return end
    if kind == "vehicle" and ComfyClient.mergeVehicle then
        ComfyClient.mergeVehicle(owner)
    elseif kind == "worldItem" and ComfyClient.mergeWorldItem then
        ComfyClient.mergeWorldItem(owner)
    end
end

function Persistence.getModDataFor(inventory, playerNum)
    if not inventory then
        return nil, false
    end

    if inventory:getType() == "floor" then
        return memoryFor(inventory), false
    end

    if playerNum then
        local player = getSpecificPlayer(playerNum)
        if player and player:getInventory() == inventory then
            return player:getModData(), true
        end
    end

    local containingItem = inventory:getContainingItem()
    if containingItem then
        mergeBucket("worldItem", containingItem)
        return containingItem:getModData(), true
    end

    local parent = inventory:getParent()

    if parent and instanceof(parent, "BaseVehicle") then
        mergeBucket("vehicle", parent)
        return parent:getModData(), true
    end

    if parent and instanceof(parent, "IsoMovingObject") then
        return memoryFor(inventory), false
    end

    if parent and instanceof(parent, "IsoObject") then
        return parent:getModData(), true
    end

    return memoryFor(inventory), false
end

local function containerKeyFor(inventory)
    local key = inventory:getType() or "unknown"
    local parent = inventory:getParent()
    if parent and instanceof(parent, "IsoObject")
            and not instanceof(parent, "IsoMovingObject") then

        local ok, count = pcall(parent.getContainerCount, parent)
        if ok and type(count) == "number" and count > 1 then
            for i = 0, count - 1 do
                if parent:getContainerByIndex(i) == inventory then
                    return key .. "#" .. i
                end
            end
        end
    end
    return key
end

function Persistence.gridDataFor(inventory, playerNum)
    local modData = Persistence.getModDataFor(inventory, playerNum)
    if not modData then
        return nil
    end

    local root = modData.ComfyGrid
    if not root then
        root = {}
        modData.ComfyGrid = root
    end

    local grids = root.grids
    if not grids then
        grids = {}
        root.grids = grids
    end

    local key = containerKeyFor(inventory)
    local gridData = grids[key]
    if not gridData then
        gridData = {}
        grids[key] = gridData
    end

    if not gridData.stacks then
        gridData.stacks = {}
    end

    return gridData
end

local function playerOwningInventory(inventory)
    local ok, count = pcall(getNumActivePlayers)
    if not ok or type(count) ~= "number" then return nil end
    for i = 0, count - 1 do
        local player = getSpecificPlayer(i)
        if player and player:getInventory() == inventory then
            return player
        end
    end
    return nil
end

function Persistence.resolveSyncOwner(inventory)
    if not inventory then return nil end
    if inventory:getType() == "floor" then return nil end

    local player = playerOwningInventory(inventory)
    if player then return player, "object" end

    local item = inventory:getContainingItem()
    if item then

        local ok, worldObj = pcall(function() return item:getWorldItem() end)
        if ok and worldObj then return worldObj, "worldItem" end
        return nil
    end

    local parent = inventory:getParent()
    if parent and instanceof(parent, "BaseVehicle") then
        return parent, "vehicle"
    end
    if parent and instanceof(parent, "IsoMovingObject") then return nil end
    if parent and instanceof(parent, "IsoObject") then
        return parent, "object"
    end
    return nil
end

function Persistence.queueSync(inventory)
    if not isClient() then return end
    local ComfyClient = ComfyGrid.Networking and ComfyGrid.Networking.ComfyClient
    if ComfyClient == nil or ComfyClient.queueModDataSync == nil then return end
    local owner, kind = Persistence.resolveSyncOwner(inventory)
    if owner ~= nil then
        ComfyClient.queueModDataSync(owner, kind)
    end
end
