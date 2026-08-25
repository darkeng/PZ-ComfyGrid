--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.3.8
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Model/ItemStack"
require "ComfyGrid/Interact/TransferJobs"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local Transfer = {}
ComfyGrid.Interact.Transfer = Transfer

local Log = ComfyGrid.Core.Log
local ItemStack = ComfyGrid.Model.ItemStack
local TransferJobs = ComfyGrid.Interact.TransferJobs

local function releaseFromCharacter(item, playerObj, playerNum)
    if playerObj.removeAttachedItem ~= nil then
        playerObj:removeAttachedItem(item)
    end
    if item:isEquipped() then
        if playerObj.isHandItem ~= nil and playerObj:isHandItem(item) then
            ISTimedActionQueue.add(ISUnequipAction:new(playerObj, item, 50))
        else
            ISInventoryPaneContextMenu.unequipItem(item, playerNum)
        end
    end
end

function Transfer.moveItems(items, destInventory, playerObj, destSlot, skipRelease)
    if not items or #items == 0 or not destInventory or not playerObj then
        return 0
    end

    local playerNum = playerObj:getPlayerNum()

    if not luautils.walkToContainer(destInventory, playerNum) then
        return 0
    end

    local order = {}
    local groups = {}
    for i = 1, #items do
        local item = items[i]
        local src = item and item:getContainer() or nil

        if src ~= nil and src ~= destInventory
                and not destInventory:isInside(item)
                and not (item:isFavorite()
                    and not destInventory:isInCharacterInventory(playerObj)) then

            if not skipRelease and src:isInCharacterInventory(playerObj) then
                releaseFromCharacter(item, playerObj, playerNum)
            end
            local group = groups[src]
            if group == nil then
                group = {}
                groups[src] = group
                order[#order + 1] = src
            end
            group[#group + 1] = item
        end
    end

    local queued = 0

    for g = 1, #order do
        local src = order[g]
        local group = groups[src]
        for i = 1, #group do

            local action = ISInventoryTransferUtil.newInventoryTransferAction(
                playerObj, group[i], src, destInventory)
            if action then

                if destSlot ~= nil and action.setComfyTarget then
                    action:setComfyTarget(destSlot)
                end

                ISTimedActionQueue.add(action)
                queued = queued + 1

                if action.setComfyTarget then
                    TransferJobs.register(src, group[i], playerObj)
                end
            end
        end
    end
    return queued
end

function Transfer.moveStacks(stacks, destInventory, playerObj, destSlot, srcInventory)
    if not stacks then return 0 end
    local items = {}
    for s = 1, #stacks do
        local stack = stacks[s]
        if type(stack) == "table" and stack.itemIDs ~= nil then
            if srcInventory ~= nil then

                local live = ItemStack.getItems(stack, srcInventory)
                for i = 1, #live do
                    items[#items + 1] = live[i]
                end
            else
                Log.warn("Transfer.moveStacks: plain grid stack without srcInventory; skipped")
            end
        elseif type(stack) == "table" and stack.items ~= nil then

            local n = #stack.items
            local first = (n >= 2) and 2 or 1
            for i = first, n do
                items[#items + 1] = stack.items[i]
            end
        elseif stack ~= nil and instanceof(stack, "InventoryItem") then
            items[#items + 1] = stack
        end
    end
    return Transfer.moveItems(items, destInventory, playerObj, destSlot)
end

function Transfer.moveStacksOrdered(stacks, destInventory, playerObj, slots, srcInventory)
    if not stacks or #stacks == 0 or not destInventory or not playerObj then
        return 0
    end
    local playerNum = playerObj:getPlayerNum()
    if not luautils.walkToContainer(destInventory, playerNum) then
        return 0
    end
    local queued = 0
    for s = 1, #stacks do
        local stack = stacks[s]
        local slot = slots and slots[s] or nil

        local items = {}
        if type(stack) == "table" and stack.itemIDs ~= nil then
            if srcInventory ~= nil then
                local live = ItemStack.getItems(stack, srcInventory)
                for i = 1, #live do items[#items + 1] = live[i] end
            else
                Log.warn("Transfer.moveStacksOrdered: plain grid stack without srcInventory; skipped")
            end
        elseif type(stack) == "table" and stack.items ~= nil then
            local n = #stack.items
            local first = (n >= 2) and 2 or 1
            for i = first, n do items[#items + 1] = stack.items[i] end
        elseif stack ~= nil and instanceof(stack, "InventoryItem") then
            items[#items + 1] = stack
        end

        for i = 1, #items do
            local item = items[i]
            local src = item and item:getContainer() or nil
            if src ~= nil and src ~= destInventory
                    and not destInventory:isInside(item)
                    and not (item:isFavorite()
                        and not destInventory:isInCharacterInventory(playerObj))

                    and src:isInCharacterInventory(playerObj) then
                releaseFromCharacter(item, playerObj, playerNum)
            end
        end
        for i = 1, #items do
            local item = items[i]
            local src = item and item:getContainer() or nil
            if src ~= nil and src ~= destInventory
                    and not destInventory:isInside(item)
                    and not (item:isFavorite()
                        and not destInventory:isInCharacterInventory(playerObj)) then
                local action = ISInventoryTransferUtil.newInventoryTransferAction(
                    playerObj, item, src, destInventory)
                if action then
                    if slot ~= nil and action.setComfyTarget then
                        action:setComfyTarget(slot)
                    end
                    ISTimedActionQueue.add(action)
                    queued = queued + 1
                    if action.setComfyTarget then
                        TransferJobs.register(src, item, playerObj)
                    end
                end
            end
        end
    end
    return queued
end

function Transfer.dropToFloor(items, playerObj)
    if not items or not playerObj then return 0 end
    local playerNum = playerObj:getPlayerNum()
    local dropped = 0
    for i = 1, #items do
        local item = items[i]

        if item ~= nil and not item:isFavorite()
                and (not instanceof(item, "Moveable") or item:CanBeDroppedOnFloor()) then
            ISInventoryPaneContextMenu.dropItem(item, playerNum)
            dropped = dropped + 1
        end
    end
    return dropped
end
