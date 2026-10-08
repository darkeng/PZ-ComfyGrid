--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/NetChannels"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Networking = ComfyGrid.Networking or {}
local ComfyClient = {}
ComfyGrid.Networking.ComfyClient = ComfyClient

local Log = ComfyGrid.Core.Log

local NetChannels = ComfyGrid.NetChannels
local COMFY_UUID = NetChannels.COMFY_UUID
local WORLD_ITEM_DATA = NetChannels.WORLD_ITEM_DATA
local WORLD_ITEM_PARTIAL = NetChannels.WORLD_ITEM_PARTIAL
local VEHICLE_DATA = NetChannels.VEHICLE_DATA
local VEHICLE_PARTIAL = NetChannels.VEHICLE_PARTIAL

ComfyClient.WORLD_ITEM_DATA = WORLD_ITEM_DATA

local ownersToTransmit = {}
local hasPending = false
local transmitFailLogged = false

function ComfyClient.queueModDataSync(owner, kind)
    if owner == nil then return end
    if not isClient() then return end
    ownersToTransmit[owner] = kind or "object"
    hasPending = true
end

function ComfyClient.getMostRecentModData(isoModData, isoKey, bucket, bucketKey)
    if isoModData == nil or bucket == nil or bucketKey == nil then
        return isoModData
    end
    local bucketData = bucket[bucketKey]
    if bucketData == nil then return isoModData end
    local isoData = isoModData[isoKey]
    if isoData == nil then
        isoModData[isoKey] = bucketData
    else
        local isoTime = isoData.lastServerTime or 0
        local bucketTime = bucketData.lastServerTime or 0
        if bucketTime > isoTime then
            isoModData[isoKey] = bucketData
        end
    end
    return isoModData
end

function ComfyClient.mergeWorldItem(item)
    if item == nil then return end
    local ok, bucket = pcall(ModData.getOrCreate, WORLD_ITEM_DATA)
    if not ok or bucket == nil then return end
    ComfyClient.getMostRecentModData(item:getModData(), "ComfyGrid",
        bucket, item:getID())
end

function ComfyClient.mergeVehicle(vehicle)
    if vehicle == nil then return end
    local ok, bucket = pcall(ModData.getOrCreate, VEHICLE_DATA)
    if not ok or bucket == nil then return end
    ComfyClient.getMostRecentModData(vehicle:getModData(), "ComfyGrid",
        bucket, vehicle:getKeyId())
end

local function transmitPartialData(fullKey, partialKey, layoutRecord)
    local fullData = ModData.getOrCreate(fullKey)
    fullData[layoutRecord[COMFY_UUID]] = layoutRecord
    ModData.add(partialKey, layoutRecord)
    ModData.transmit(partialKey)
end

local function transmitWorldItem(worldObj)
    local item = worldObj:getItem()
    local layoutRecord = item and item:getModData().ComfyGrid
    if layoutRecord == nil then return end
    layoutRecord[COMFY_UUID] = item:getID()
    transmitPartialData(WORLD_ITEM_DATA, WORLD_ITEM_PARTIAL, layoutRecord)
end

local function transmitItemLayout(item)
    local layoutRecord = item:getModData().ComfyGrid
    if layoutRecord == nil then return end
    layoutRecord[COMFY_UUID] = item:getID()
    transmitPartialData(WORLD_ITEM_DATA, WORLD_ITEM_PARTIAL, layoutRecord)
end

local function transmitVehicle(vehicle)
    local layoutRecord = vehicle:getModData().ComfyGrid
    if layoutRecord == nil then return end
    layoutRecord[COMFY_UUID] = vehicle:getKeyId()
    transmitPartialData(VEHICLE_DATA, VEHICLE_PARTIAL, layoutRecord)
end

local function transmitObject(owner)
    owner:transmitModData()
end

local function transmitOwner(owner)

    if instanceof(owner, "IsoWorldInventoryObject") then
        transmitWorldItem(owner)
    elseif instanceof(owner, "BaseVehicle") then
        transmitVehicle(owner)

    elseif instanceof(owner, "InventoryItem") then
        transmitItemLayout(owner)
    elseif owner.transmitModData then
        transmitObject(owner)
    end
end

local function drainTransmitQueue()
    if not hasPending then return end
    for owner in pairs(ownersToTransmit) do
        ownersToTransmit[owner] = nil
        local ok, err = pcall(transmitOwner, owner)
        if not ok and not transmitFailLogged then
            transmitFailLogged = true
            Log.warn("ComfyClient: sync transmit failed (logged once): "
                .. tostring(err))
        end
    end
    hasPending = false
end

function ComfyClient.flush()
    local ok, err = pcall(drainTransmitQueue)
    if not ok then
        Log.error("ComfyClient flush failed: " .. tostring(err))
    end
    return ok
end

local function onReceiveGlobalModData(key, data)

    if isServer() or type(data) ~= "table" then return end
    if key == WORLD_ITEM_DATA then
        ModData.add(WORLD_ITEM_DATA, data)
    elseif key == VEHICLE_DATA then
        ModData.add(VEHICLE_DATA, data)
    elseif key == WORLD_ITEM_PARTIAL or key == VEHICLE_PARTIAL then
        local uuid = data[COMFY_UUID]
        if uuid == nil then return end
        local fullKey = (key == WORLD_ITEM_PARTIAL)
            and WORLD_ITEM_DATA or VEHICLE_DATA
        ModData.getOrCreate(fullKey)[uuid] = data
    end
end

if not ComfyGrid.Networking._comfyClientHooked then
    ComfyGrid.Networking._comfyClientHooked = true

    Events.OnTick.Add(function()
        local ok, err = pcall(drainTransmitQueue)
        if not ok then
            Log.error("ComfyClient drain failed: " .. tostring(err))
        end
    end)

    Events.OnLoad.Add(function()
        if not isClient() then return end
        pcall(ModData.request, WORLD_ITEM_DATA)
        pcall(ModData.request, VEHICLE_DATA)
    end)

    Events.OnReceiveGlobalModData.Add(function(key, data)
        local ok, err = pcall(onReceiveGlobalModData, key, data)
        if not ok then
            Log.warn("ComfyClient: OnReceiveGlobalModData failed: "
                .. tostring(err))
        end
    end)
end
