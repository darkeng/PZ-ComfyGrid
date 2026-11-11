--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.10.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Util"
require "ComfyGrid/Model/ContainerSide"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local ItemVeil = {}
ComfyGrid.Model.ItemVeil = ItemVeil

local Log = ComfyGrid.Core.Log
local Util = ComfyGrid.Core.Util
local ContainerSide = ComfyGrid.Model.ContainerSide

local providers = {}

local providerCount = 0
local progressCount = 0

local function recount()
    providerCount, progressCount = 0, 0
    for _, provider in pairs(providers) do
        providerCount = providerCount + 1
        if provider.progress ~= nil then progressCount = progressCount + 1 end
    end
end

function ItemVeil.register(name, fn, progressFn)
    if type(name) ~= "string" or type(fn) ~= "function" then return false end
    if type(progressFn) ~= "function" then progressFn = nil end
    providers[name] = { veil = fn, progress = progressFn }
    recount()
    return true
end

function ItemVeil.unregister(name)
    providers[name] = nil
    recount()
end

local function dropFailing(name, err)
    ItemVeil.unregister(name)
    Log.warn("ItemVeil: provider '" .. name .. "' failed and was dropped: " .. tostring(err))
end

function ItemVeil.isActive()
    return providerCount > 0
end

function ItemVeil.isCarried(container, playerNum)
    return ContainerSide.isCarried(container, getSpecificPlayer(playerNum or 0))
end
local isCarried = ItemVeil.isCarried

local function anyProviderVeils(container, item, playerNum)
    for name, provider in pairs(providers) do
        local ok, veiled = pcall(provider.veil, container, item, playerNum)
        if not ok then
            dropFailing(name, veiled)
        elseif veiled == true then
            return true
        end
    end
    return false
end

local function memberOf(container, itemById, id)
    local member = itemById ~= nil and itemById[id] or nil
    if member == nil then member = container:getItemWithID(id) end
    return member
end

function ItemVeil.isVeiled(container, item, playerNum)
    if providerCount == 0 or item == nil then return false end
    if isCarried(container, playerNum) then return false end
    return anyProviderVeils(container, item, playerNum)
end

function ItemVeil.boardVeils(container, playerNum)
    return providerCount > 0 and container ~= nil and not isCarried(container, playerNum)
end

function ItemVeil.membersVeiled(stack, container, playerNum, itemById)
    local ids = stack ~= nil and stack.itemIDs or nil
    if type(ids) ~= "table" then return false end
    for id in pairs(ids) do
        local member = memberOf(container, itemById, id)
        if member ~= nil and anyProviderVeils(container, member, playerNum) then
            return true
        end
    end
    return false
end

function ItemVeil.stackIsVeiled(stack, container, playerNum, itemById)
    if stack == nil or not ItemVeil.boardVeils(container, playerNum) then return false end
    return ItemVeil.membersVeiled(stack, container, playerNum, itemById)
end

function ItemVeil.hasProgress()
    return progressCount > 0
end

function ItemVeil.progressOf(action, container, item)
    if progressCount == 0 or action == nil or item == nil then return nil end
    for name, provider in pairs(providers) do
        if provider.progress ~= nil then
            local ok, progress = pcall(provider.progress, action, container, item)
            if not ok then
                dropFailing(name, progress)
            elseif type(progress) == "number" then
                return Util.clamp(progress, 0, 1)
            end
        end
    end
    return nil
end

function ItemVeil.stackProgress(stack, container, action, itemById)
    if progressCount == 0 or action == nil or stack == nil or container == nil then return nil end
    local ids = stack.itemIDs
    if type(ids) ~= "table" then return nil end
    local furthest = nil
    for id in pairs(ids) do
        local member = memberOf(container, itemById, id)
        if member ~= nil then
            local progress = ItemVeil.progressOf(action, container, member)
            if progress ~= nil and (furthest == nil or progress > furthest) then
                furthest = progress
            end
        end
    end
    return furthest
end

return ItemVeil
