--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.10.1
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Input"
require "ComfyGrid/Settings"
require "ComfyGrid/Interact/TransferJobs"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local HotbarAttach = {}
ComfyGrid.Interact.HotbarAttach = HotbarAttach

local Log = ComfyGrid.Core.Log
local Input = ComfyGrid.Core.Input
local Settings = ComfyGrid.Settings
local TransferJobs = ComfyGrid.Interact.TransferJobs

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

local function announceAttach(playerObj, item)

    if syncItemFields ~= nil then pcall(syncItemFields, playerObj, item) end

    if ISInventoryPage ~= nil then ISInventoryPage.renderDirty = true end

end

function HotbarAttach.onArrived(playerNum, itemId, location, slotIndex, slotDef,
                                onDisplaced)
    local playerObj = getSpecificPlayer(playerNum)
    local hotbar = Input.hotbarOf(playerNum)
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
    announceAttach(playerObj, item)
    if prev ~= nil and onDisplaced ~= nil then pcall(onDisplaced, prev) end
end

function HotbarAttach.attach(playerNum, item, slotIndex, slotDef, onDisplaced)
    local playerObj = getSpecificPlayer(playerNum)
    local hotbar = Input.hotbarOf(playerNum)
    if playerObj == nil or hotbar == nil or item == nil then return false end
    local location = locationFor(item, slotDef)

    if location == nil then return false end

    local needsFetch = false
    local okH, mustFetch = pcall(luautils.haveToBeTransfered, playerObj, item)
    if okH then needsFetch = mustFetch == true end
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

local PENDING_GRACE_MS = 2000

local pendingWeapons = {}

local function takesASlot(item)
    if item == nil or not instanceof(item, "HandWeapon") or item:isBroken() then
        return false
    end
    return item:getMaxDamage() > 0 or item:getExplosionPower() > 0
        or item:getFireStartingChance() > 0
end
HotbarAttach.takesASlot = takesASlot

function HotbarAttach.freeSlotFor(hotbar, item)
    if hotbar == nil or item == nil or hotbar.availableSlot == nil then return nil end
    local attached = hotbar.attachedItems or {}
    local chosen = nil
    for slotIndex, slot in pairs(hotbar.availableSlot) do
        if (chosen == nil or slotIndex < chosen) and attached[slotIndex] == nil then
            local ok, fits = pcall(hotbar.canBeAttached, hotbar, slot, item)
            if ok and fits then chosen = slotIndex end
        end
    end
    return chosen
end

local function modelLocationFor(hotbar, item, slotDef)
    local location = locationFor(item, slotDef)
    if slotDef.name == "Back" and hotbar.replacements ~= nil then
        local replacement = hotbar.replacements[item:getAttachmentType()]
        if replacement ~= nil then location = replacement end
    end
    return location
end

local function reserve(playerObj, hotbar, item, slotIndex)
    local slotDef = hotbar.availableSlot[slotIndex].def
    item:setAttachedSlot(slotIndex)
    item:setAttachedSlotType(slotDef.type)
    item:setAttachedToModel(modelLocationFor(hotbar, item, slotDef))
    hotbar:reloadIcons()
    announceAttach(playerObj, item)
end

local function heldWithId(playerObj, itemId)
    local primary = playerObj:getPrimaryHandItem()
    if primary ~= nil and primary:getID() == itemId then return primary end
    local secondary = playerObj:getSecondaryHandItem()
    if secondary ~= nil and secondary:getID() == itemId then return secondary end
    return nil
end

local function settle(entry, now)
    local playerObj = entry.playerObj
    local item = heldWithId(playerObj, entry.itemId)
    if item == nil then
        local queued = TransferJobs.queuedActions(playerObj)
        if queued ~= nil and #queued > 0 then
            entry.emptySinceMs = nil
            return false
        end
        if entry.emptySinceMs == nil then entry.emptySinceMs = now end
        return now - entry.emptySinceMs > PENDING_GRACE_MS
    end
    if item:getAttachedSlot() == -1 then
        local hotbar = Input.hotbarOf(playerObj:getPlayerNum())
        local slotIndex = HotbarAttach.freeSlotFor(hotbar, item)
        if slotIndex ~= nil then reserve(playerObj, hotbar, item, slotIndex) end
    end
    return true
end

function HotbarAttach._onPlayerUpdate(playerObj)
    if #pendingWeapons == 0 then return end
    local now = getTimestampMs()
    for i = #pendingWeapons, 1, -1 do
        local entry = pendingWeapons[i]
        if entry.playerObj == playerObj then
            local ok, done = pcall(settle, entry, now)
            if not ok then
                Log.warn("HotbarAttach: reservation failed: " .. tostring(done))
            end
            if not ok or done then table.remove(pendingWeapons, i) end
        end
    end
end

function HotbarAttach.reserveAfterEquip(playerObj, item)
    if Settings.get("WEAPON_TO_HOTBAR") ~= true then return end
    if playerObj == nil or not takesASlot(item) then return end
    if playerObj:isHandItem(item) or item:getAttachedSlot() ~= -1 then return end
    local hotbar = Input.hotbarOf(playerObj:getPlayerNum())
    if HotbarAttach.freeSlotFor(hotbar, item) == nil then return end
    pendingWeapons[#pendingWeapons + 1] = { playerObj = playerObj, itemId = item:getID() }
end

function HotbarAttach.isPending(itemId)
    for i = 1, #pendingWeapons do
        if pendingWeapons[i].itemId == itemId then return true end
    end
    return false
end

if not ComfyGrid._hotbarReserveHooked then
    ComfyGrid._hotbarReserveHooked = true
    Events.OnPlayerUpdate.Add(function(playerObj)
        local hotbarAttach = ComfyGrid.Interact and ComfyGrid.Interact.HotbarAttach
        if hotbarAttach ~= nil then hotbarAttach._onPlayerUpdate(playerObj) end
    end)
end
