--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.3.7
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

local COMFY_UUID = "ComfyGrid_UUID"
local WORLD_ITEM_DATA = "ComfyGrid_WorldItemData"
local WORLD_ITEM_PARTIAL = "ComfyGrid_WorldItemPartial"
local VEHICLE_DATA = "ComfyGrid_VehicleData"
local VEHICLE_PARTIAL = "ComfyGrid_VehiclePartial"

local validKeys = {
    [WORLD_ITEM_PARTIAL] = true,
    [VEHICLE_PARTIAL] = true,
}

local ComfyServer = {}

local function getOrCreateUuid(record)
    local uuid = record[COMFY_UUID]
    if not uuid then
        uuid = getRandomUUID()
        record[COMFY_UUID] = uuid
    end
    return uuid
end

local function validateTimestamps(existing, incoming)
    if not existing.lastServerTime then return true end
    if not incoming.lastServerTime then return false end
    return incoming.lastServerTime == existing.lastServerTime
end

local function handlePartialData(fullKey, partialKey, incoming)
    local uuid = getOrCreateUuid(incoming)
    local fullData = ModData.getOrCreate(fullKey)
    local existing = fullData[uuid]

    if not existing or validateTimestamps(existing, incoming) then
        incoming.lastServerTime = getTimestampMs()
    else

        incoming = existing
    end

    fullData[uuid] = incoming
    ModData.add(partialKey, incoming)
    ModData.transmit(partialKey)
end

local function onServerReceiveGlobalModData(key, data)

    if not isServer() or not validKeys[key] or type(data) ~= "table" then
        return
    end
    if key == WORLD_ITEM_PARTIAL then
        handlePartialData(WORLD_ITEM_DATA, WORLD_ITEM_PARTIAL, data)
    elseif key == VEHICLE_PARTIAL then
        handlePartialData(VEHICLE_DATA, VEHICLE_PARTIAL, data)
    end
end

Events.OnReceiveGlobalModData.Add(onServerReceiveGlobalModData)

return ComfyServer
