--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Util"
require "ComfyGrid/Settings"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local Capacity = {}
ComfyGrid.Model.Capacity = Capacity

local Util = ComfyGrid.Core.Util
local Settings = ComfyGrid.Settings

local MAX_SLOTS = 200

local MIN_SLOTS = 2
local FLOOR_SLOTS = 80
local FALLBACK_CAPACITY = 20

function Capacity.effectiveFor(inventory, playerNum)
    if inventory == nil then return nil end
    if playerNum ~= nil and inventory.getEffectiveCapacity ~= nil then
        local okPlayer, playerObj = pcall(getSpecificPlayer, playerNum)
        if okPlayer and playerObj ~= nil then
            local okEffective, effectiveCapacity = pcall(
                inventory.getEffectiveCapacity, inventory, playerObj)
            if okEffective and type(effectiveCapacity) == "number" then
                return effectiveCapacity
            end
        end
    end
    local okCapacity, baseCapacity = pcall(inventory.getCapacity, inventory)
    if okCapacity and type(baseCapacity) == "number" then return baseCapacity end
    return nil
end

local WEIGHT_TTL_MS = 100
local WEIGHT_MEMO_MAX = 256
local weightMemo = {}
local weightMemoCount = 0
local weightGen = 0

function Capacity.flushWeights()
    weightGen = weightGen + 1
end

function Capacity.weightOf(inventory, signal)
    if inventory == nil then return nil end
    local now = getTimestampMs()
    local memoEntry = weightMemo[inventory]
    if memoEntry ~= nil and memoEntry.generation == weightGen
            and memoEntry.signal == signal
            and now - memoEntry.readAtMs < WEIGHT_TTL_MS
            and not inventory:isDrawDirty() then
        return memoEntry.weight
    end
    local okWeight, contentsWeight = pcall(inventory.getCapacityWeight, inventory)
    if not okWeight or type(contentsWeight) ~= "number" then return nil end
    if memoEntry == nil then

        if weightMemoCount >= WEIGHT_MEMO_MAX then
            weightMemo = {}
            weightMemoCount = 0
        end
        memoEntry = {}
        weightMemo[inventory] = memoEntry
        weightMemoCount = weightMemoCount + 1
    end
    memoEntry.weight, memoEntry.readAtMs = contentsWeight, now
    memoEntry.generation, memoEntry.signal = weightGen, signal
    return contentsWeight
end

local function isFloor(inventory)
    return inventory:getType() == "floor"
end

local function characterOwnerOf(inventory)
    local okParent, parent = pcall(inventory.getParent, inventory)
    if okParent and parent ~= nil and instanceof(parent, "IsoGameCharacter") then
        return parent
    end
    return nil
end

function Capacity.isFull(inventory, playerNum, signal)
    if inventory == nil then return false end
    local okFloor, onFloor = pcall(isFloor, inventory)
    if okFloor and onFloor then return false end

    if characterOwnerOf(inventory) ~= nil then return false end
    local currentLoad = Capacity.weightOf(inventory, signal)
    if type(currentLoad) ~= "number" then return false end
    local capacity = Capacity.effectiveFor(inventory, playerNum)
    if type(capacity) ~= "number" or capacity <= 0 then return false end
    return currentLoad >= capacity
end

function Capacity.slotsFor(inventory, playerNum)
    if inventory and isFloor(inventory) then
        return FLOOR_SLOTS
    end

    local capacity = FALLBACK_CAPACITY
    if inventory then

        local value = Capacity.effectiveFor(inventory, playerNum)
        if type(value) == "number" then
            capacity = value
        end

        local character = characterOwnerOf(inventory)
        if character ~= nil and character.getMaxWeight ~= nil then
            local okMaxWeight, maxWeight = pcall(character.getMaxWeight, character)
            if okMaxWeight and type(maxWeight) == "number" and maxWeight > 0 then
                capacity = maxWeight
            end
        end
    end

    return Util.clamp(
        math.ceil(capacity * Settings.get("SLOTS_PER_CAPACITY")),
        MIN_SLOTS, MAX_SLOTS)
end
