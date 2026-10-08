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
local Persistence = {}
ComfyGrid.Model.Persistence = Persistence

local memoryModData = {}
local memoryAccessMs = {}
local memoryCount = 0
local MAX_MEMORY_ENTRIES = 64

local function evictOldestMemory()
    local oldestKey, oldestMs
    for inventory, accessMs in pairs(memoryAccessMs) do
        if oldestMs == nil or accessMs < oldestMs then
            oldestKey, oldestMs = inventory, accessMs
        end
    end
    if oldestKey ~= nil then
        memoryModData[oldestKey] = nil
        memoryAccessMs[oldestKey] = nil
        memoryCount = memoryCount - 1
    end
end

local function memoryFor(inventory)
    local memoryTable = memoryModData[inventory]
    if memoryTable == nil then
        if memoryCount >= MAX_MEMORY_ENTRIES then
            evictOldestMemory()
        end
        memoryTable = {}
        memoryModData[inventory] = memoryTable
        memoryCount = memoryCount + 1
    end
    memoryAccessMs[inventory] = getTimestampMs()
    return memoryTable
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

local ANY_LOCAL_SEAT = {}

local PERSISTENT_RUNG = { player = true, bag = true, vehicle = true, object = true }

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

local function playerForSeat(inventory, seat)
    if seat == ANY_LOCAL_SEAT then return playerOwningInventory(inventory) end
    if not seat then return nil end
    local player = getSpecificPlayer(seat)
    if player and player:getInventory() == inventory then return player end
    return nil
end

local function ownerOf(inventory, seat)
    if inventory:getType() == "floor" then return nil, "floor" end

    local player = playerForSeat(inventory, seat)
    if player then return player, "player" end

    local containingItem = inventory:getContainingItem()
    if containingItem then return containingItem, "bag" end

    local parent = inventory:getParent()
    if parent and instanceof(parent, "BaseVehicle") then return parent, "vehicle" end
    if parent and instanceof(parent, "IsoMovingObject") then return parent, "mover" end
    if parent and instanceof(parent, "IsoObject") then return parent, "object" end
    return parent, "none"
end

function Persistence.ownerOf(inventory, playerNum)
    if not inventory then return nil, nil end
    return ownerOf(inventory, playerNum)
end

function Persistence.getModDataFor(inventory, playerNum)
    if not inventory then
        return nil, false
    end
    local owner, rung = ownerOf(inventory, playerNum)
    if rung == "bag" then
        mergeBucket("worldItem", owner)
    elseif rung == "vehicle" then
        mergeBucket("vehicle", owner)
    end
    if PERSISTENT_RUNG[rung] then
        return owner:getModData(), true
    end
    return memoryFor(inventory), false
end

function Persistence.isPersistent(inventory, playerNum)
    if not inventory then return false end
    local _, rung = ownerOf(inventory, playerNum)
    return PERSISTENT_RUNG[rung] == true
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

function Persistence.resolveSyncOwner(inventory)
    if not inventory then return nil end
    local owner, rung = ownerOf(inventory, ANY_LOCAL_SEAT)
    if rung == "player" or rung == "object" then return owner, "object" end
    if rung == "vehicle" then return owner, "vehicle" end
    if rung == "bag" then

        local ok, worldObj = pcall(function() return owner:getWorldItem() end)
        if ok and worldObj then return worldObj, "worldItem" end
    end
    return nil
end

function Persistence.queueItemSync(item)
    if not isClient() then return end
    if item == nil then return end
    local ComfyClient = ComfyGrid.Networking and ComfyGrid.Networking.ComfyClient
    if ComfyClient == nil or ComfyClient.queueModDataSync == nil then return end
    ComfyClient.queueModDataSync(item, "worldItem")
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
