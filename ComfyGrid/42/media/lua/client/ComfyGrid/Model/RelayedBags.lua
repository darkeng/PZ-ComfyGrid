--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.5
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local RelayedBags = {}
ComfyGrid.Model.RelayedBags = RelayedBags

RelayedBags.LOWERING = "lowering"

RelayedBags.OUT = "out"

RelayedBags.RETURNING = "returning"

local entriesById = {}

local entryCount = 0

function RelayedBags.add(entry)
    if entriesById[entry.bagId] == nil then entryCount = entryCount + 1 end
    entry.phase = RelayedBags.LOWERING
    entry.phaseSinceMs = getTimestampMs()
    entriesById[entry.bagId] = entry
end

function RelayedBags.get(bagId)
    return entriesById[bagId]
end

function RelayedBags.setPhase(entry, phase)
    entry.phase = phase
    entry.phaseSinceMs = getTimestampMs()
end

function RelayedBags.remove(bagId)
    if entriesById[bagId] == nil then return end
    entriesById[bagId] = nil
    entryCount = entryCount - 1
end

function RelayedBags.count()
    return entryCount
end

function RelayedBags.each()
    return pairs(entriesById)
end

local function idOf(item)
    if item == nil or not instanceof(item, "InventoryItem") then return nil end
    return item:getID()
end

function RelayedBags.isInTransit(bagItem)
    if entryCount == 0 then return false end
    local bagId = idOf(bagItem)
    local entry = bagId ~= nil and entriesById[bagId] or nil
    return entry ~= nil and entry.phase ~= RelayedBags.OUT
end

function RelayedBags.isOutInventory(inventory)
    if entryCount == 0 or inventory == nil then return false end
    if not instanceof(inventory, "ItemContainer") then return false end
    local entry = entriesById[idOf(inventory:getContainingItem())]
    return entry ~= nil and entry.phase ~= RelayedBags.LOWERING
end
