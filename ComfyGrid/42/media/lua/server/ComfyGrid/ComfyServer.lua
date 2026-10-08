--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/NetChannels"

local NetChannels = ComfyGrid.NetChannels
local COMFY_UUID = NetChannels.COMFY_UUID
local WORLD_ITEM_DATA = NetChannels.WORLD_ITEM_DATA
local WORLD_ITEM_PARTIAL = NetChannels.WORLD_ITEM_PARTIAL
local VEHICLE_DATA = NetChannels.VEHICLE_DATA
local VEHICLE_PARTIAL = NetChannels.VEHICLE_PARTIAL

local PARTIAL_CHANNELS = {
    [WORLD_ITEM_PARTIAL] = true,
    [VEHICLE_PARTIAL] = true,
}

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

    if not isServer() or not PARTIAL_CHANNELS[key] or type(data) ~= "table" then
        return
    end
    if key == WORLD_ITEM_PARTIAL then
        handlePartialData(WORLD_ITEM_DATA, WORLD_ITEM_PARTIAL, data)
    elseif key == VEHICLE_PARTIAL then
        handlePartialData(VEHICLE_DATA, VEHICLE_PARTIAL, data)
    end
end

Events.OnReceiveGlobalModData.Add(onServerReceiveGlobalModData)
