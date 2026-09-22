--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.8
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local HotbarAttach = {}
ComfyGrid.Interact.HotbarAttach = HotbarAttach

local Log = ComfyGrid.Core.Log

local function locationFor(item, slotDef)
    if item == nil or slotDef == nil or slotDef.attachments == nil then return nil end
    local okT, attachType = pcall(item.getAttachmentType, item)
    if not okT or attachType == nil then return nil end
    return slotDef.attachments[attachType]
end

local function evict(playerObj, prev)
    if prev == nil then return end
    pcall(playerObj.removeAttachedItem, playerObj, prev)
    pcall(prev.setAttachedSlot, prev, -1)
    pcall(prev.setAttachedSlotType, prev, nil)
    pcall(prev.setAttachedToModel, prev, nil)
    if syncItemFields ~= nil then pcall(syncItemFields, playerObj, prev) end
end

function HotbarAttach.onArrived(playerNum, itemId, location, slotIndex, slotDef,
                                onDisplaced)
    local playerObj = getSpecificPlayer(playerNum)
    local hotbar = getPlayerHotbar(playerNum)
    if playerObj == nil or hotbar == nil then return end
    local inv = playerObj:getInventory()
    local okI, item = pcall(inv.getItemById, inv, itemId)
    if not okI or item == nil then return end

    local prev = hotbar.attachedItems ~= nil and hotbar.attachedItems[slotIndex] or nil
    if prev == item then prev = nil end
    evict(playerObj, prev)

    local okA, err = pcall(hotbar.attachItem, hotbar, item, location, slotIndex,
        slotDef, false)
    if not okA then
        Log.warn("HotbarAttach: attach on arrival failed: " .. tostring(err))
        return
    end

    if syncItemFields ~= nil then pcall(syncItemFields, playerObj, item) end

    if ISInventoryPage ~= nil then ISInventoryPage.renderDirty = true end

    if prev ~= nil and onDisplaced ~= nil then pcall(onDisplaced, prev) end
end

function HotbarAttach.attach(playerNum, item, slotIndex, slotDef, onDisplaced)
    local playerObj = getSpecificPlayer(playerNum)
    local hotbar = getPlayerHotbar(playerNum)
    if playerObj == nil or hotbar == nil or item == nil then return false end
    local location = locationFor(item, slotDef)

    if location == nil then return false end

    local needsFetch = false
    local okH, res = pcall(luautils.haveToBeTransfered, playerObj, item)
    if okH then needsFetch = res == true end
    if not needsFetch then
        local prev = hotbar.attachedItems ~= nil and hotbar.attachedItems[slotIndex] or nil
        if prev == item then prev = nil end
        local okA, err = pcall(hotbar.attachItem, hotbar, item, location,
            slotIndex, slotDef, true)
        if not okA then
            Log.warn("HotbarAttach: vanilla attach failed: " .. tostring(err))
            return false
        end
        if prev ~= nil and onDisplaced ~= nil then pcall(onDisplaced, prev) end
        return true
    end

    local src = item:getContainer()
    local action = nil
    local okN, made = pcall(ISInventoryTransferUtil.newInventoryTransferAction,
        playerObj, item, src, playerObj:getInventory())
    if okN then action = made end

    if action == nil or action.setOnComplete == nil then
        local okV, err = pcall(hotbar.attachItem, hotbar, item, location,
            slotIndex, slotDef, true)
        if not okV then Log.warn("HotbarAttach: fallback failed: " .. tostring(err)) end
        return okV == true
    end
    action:setOnComplete(HotbarAttach.onArrived, playerNum, item:getID(),
        location, slotIndex, slotDef, onDisplaced)
    ISTimedActionQueue.add(action)
    return true
end
