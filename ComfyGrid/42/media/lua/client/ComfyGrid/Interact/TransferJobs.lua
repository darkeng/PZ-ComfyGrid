--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.2.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local TransferJobs = {}
ComfyGrid.Interact.TransferJobs = TransferJobs

local MAX_OVERLAY_ITEMS = 256

local ALIVE_CHECK_MS = 1000

local registry = {}

local function entryFor(container)
    local entry = registry[container]
    if entry == nil then
        entry = { items = {}, count = 0, character = nil, lastAliveMs = 0 }
        registry[container] = entry
    end
    return entry
end

function TransferJobs.register(container, item, character)
    if container == nil or item == nil then return end
    local entry = entryFor(container)
    local id = item:getID()
    if entry.items[id] == nil then
        entry.count = entry.count + 1
    end
    entry.items[id] = item
    entry.character = character or entry.character

    entry.lastAliveMs = getTimestampMs()
end

function TransferJobs.unregister(container, item)
    if container == nil or item == nil then return end
    local entry = registry[container]
    if entry == nil then return end
    local ok, id = pcall(item.getID, item)
    if not ok then return end
    if entry.items[id] ~= nil then
        entry.items[id] = nil
        entry.count = entry.count - 1
        if entry.count <= 0 then
            registry[container] = nil
        end
    end
end

local function queueStillMoving(character, container)
    if character == nil then return false end
    local queues = ISTimedActionQueue.queues
    local q = queues ~= nil and queues[character] or nil
    local list = q ~= nil and q.queue or nil
    if list == nil then return false end
    for i = 1, #list do
        local action = list[i]
        if action ~= nil and action.Type == "ISInventoryTransferAction"
                and action.srcContainer == container then
            return true
        end
    end
    return false
end

function TransferJobs.itemsFor(container)
    if container == nil then return nil end
    local entry = registry[container]
    if entry == nil then return nil end
    local now = getTimestampMs()
    if now - entry.lastAliveMs >= ALIVE_CHECK_MS then
        entry.lastAliveMs = now
        for id, item in pairs(entry.items) do
            local ok, cont = pcall(item.getContainer, item)
            if not ok or cont ~= container then
                entry.items[id] = nil
                entry.count = entry.count - 1
            end
        end
        if entry.count <= 0 or not queueStillMoving(entry.character, container) then
            registry[container] = nil
            return nil
        end
    end
    if entry.count > MAX_OVERLAY_ITEMS then return nil end
    return entry.items
end
