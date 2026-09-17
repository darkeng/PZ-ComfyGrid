--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.2
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

local function isFloor(inventory)
    local ok, invType = pcall(inventory.getType, inventory)
    return ok and tostring(invType) == "floor"
end

local function transferSourceOf(item, destInventory, playerObj, destIsFloor)
    local src = item ~= nil and item:getContainer() or nil
    if src == nil or src == destInventory then return nil end
    if destInventory:isInside(item) then return nil end
    if not destIsFloor and not destInventory:isItemAllowed(item) then
        return nil
    end
    if item:isFavorite()
            and not destInventory:isInCharacterInventory(playerObj) then
        return nil
    end
    return src
end

local function alwaysAdmit() return true end

local function newWeightBudget(destInventory, playerObj)
    local total, toFloor = 0, 0
    local destSq = destInventory:hasWorldItem()
        and destInventory:getWorldItem():getSquare() or nil
    return function(item)
        local w = item:getUnequippedWeight()
        local newToFloor = toFloor
        if destSq == nil or not item:isOnGroundOrInsideBagOnSquare(destSq) then
            newToFloor = toFloor + w
        end
        if not destInventory:hasRoomFor(playerObj, total + w, newToFloor) then
            return false
        end
        total = total + w
        toFloor = newToFloor
        return true
    end
end

local function admissionFor(destInventory, playerObj, skipBudget)
    local floor = isFloor(destInventory)
    if floor or skipBudget then
        return floor, alwaysAdmit
    end
    return false, newWeightBudget(destInventory, playerObj)
end

local function sortLightestFirst(items)
    local index = {}
    for i = 1, #items do index[items[i]] = i end
    table.sort(items, function(a, b)
        local wa, wb = a:getUnequippedWeight(), b:getUnequippedWeight()
        if wa ~= wb then return wa < wb end
        return index[a] < index[b]
    end)
end

function Transfer.escalateHeavyItems(items, destInventory, playerObj)
    local remaining, carried = {}, 0
    if not items or not destInventory or not playerObj then
        return items or remaining, 0
    end

    local own = destInventory == playerObj:getInventory()
    if not own then
        local okOwn, inChar = pcall(destInventory.isInCharacterInventory,
            destInventory, playerObj)
        own = okOwn and inChar == true
    end
    for i = 1, #items do
        local item = items[i]
        local src = item ~= nil and item:getContainer() or nil
        if own and src ~= nil and src ~= destInventory
                and isForceDropHeavyItem(item) then
            ISInventoryPaneContextMenu.equipHeavyItem(playerObj, item)
            carried = carried + 1
        else
            remaining[#remaining + 1] = item
        end
    end
    return remaining, carried
end

local function extinguishForFloor(item, playerNum)
    if not item:isEquipped() then return false end
    if item:getType() == "CandleLit" then
        ISInventoryPaneContextMenu.litCandleExtinguish(item, playerNum)
        return true
    end
    if item:getType() == "Lantern_HurricaneLit"
            or item:hasTag(ItemTag.LIT_LANTERN) then
        ISInventoryPaneContextMenu.hurricaneLanternExtinguish(item, playerNum)
        return true
    end
    return false
end

function Transfer.moveItems(items, destInventory, playerObj, destSlot,
        skipRelease, skipBudget)
    if not items or #items == 0 or not destInventory or not playerObj then
        return 0
    end

    local playerNum = playerObj:getPlayerNum()

    local destIsFloor, admit = admissionFor(destInventory, playerObj,
        skipBudget)

    local sorted = {}
    for i = 1, #items do
        if items[i] ~= nil then sorted[#sorted + 1] = items[i] end
    end
    sortLightestFirst(sorted)

    local admitted, sources = {}, {}
    for i = 1, #sorted do
        local item = sorted[i]
        local src = transferSourceOf(item, destInventory, playerObj,
            destIsFloor)
        if src ~= nil and admit(item) then
            admitted[#admitted + 1] = item
            sources[#sources + 1] = src
        end
    end
    if #admitted == 0 then return 0 end

    if not luautils.walkToContainer(destInventory, playerNum) then
        return 0
    end

    local extra = 0

    local order = {}
    local groups = {}
    for i = 1, #admitted do
        local item = admitted[i]
        local src = sources[i]
        if destIsFloor and extinguishForFloor(item, playerNum) then
            extra = extra + 1
        else

            if not skipRelease
                    and src:isInCharacterInventory(playerObj) then
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
    return queued + extra
end

function Transfer.moveStacks(stacks, destInventory, playerObj, destSlot,
        srcInventory, skipBudget)
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
    return Transfer.moveItems(items, destInventory, playerObj, destSlot, nil,
        skipBudget)
end

function Transfer.moveStacksOrdered(stacks, destInventory, playerObj, slots, srcInventory)
    if not stacks or #stacks == 0 or not destInventory or not playerObj then
        return 0
    end
    local playerNum = playerObj:getPlayerNum()

    local destIsFloor, admit = admissionFor(destInventory, playerObj)

    local plan = {}
    local admittedTotal = 0
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

        local admitted = {}
        local sources = {}
        for i = 1, #items do
            local item = items[i]
            local src = transferSourceOf(item, destInventory, playerObj,
                destIsFloor)
            if src ~= nil and admit(item) then
                admitted[#admitted + 1] = item
                sources[#sources + 1] = src
            end
        end
        admittedTotal = admittedTotal + #admitted
        plan[s] = { slot = slot, admitted = admitted, sources = sources }
    end
    if admittedTotal == 0 then return 0 end

    if not luautils.walkToContainer(destInventory, playerNum) then
        return 0
    end

    local queued, extra = 0, 0
    for s = 1, #plan do
        local entry = plan[s]
        local slot = entry.slot
        local admitted, sources = entry.admitted, entry.sources

        for i = 1, #admitted do
            if sources[i]:isInCharacterInventory(playerObj) then
                releaseFromCharacter(admitted[i], playerObj, playerNum)
            end
        end
        for i = 1, #admitted do
            local item = admitted[i]
            if destIsFloor and extinguishForFloor(item, playerNum) then
                extra = extra + 1
            else
                local action = ISInventoryTransferUtil.newInventoryTransferAction(
                    playerObj, item, sources[i], destInventory)
                if action then
                    if slot ~= nil and action.setComfyTarget then
                        action:setComfyTarget(slot)
                    end
                    ISTimedActionQueue.add(action)
                    queued = queued + 1
                    if action.setComfyTarget then
                        TransferJobs.register(sources[i], item, playerObj)
                    end
                end
            end
        end
    end
    return queued + extra
end

function Transfer.canDropOutsideVehicle(playerObj)
    if playerObj == nil then return true end
    local okVehicle, vehicle = pcall(playerObj.getVehicle, playerObj)
    if not okVehicle or vehicle == nil then return true end
    local okSeat, seat = pcall(vehicle.getSeat, vehicle, playerObj)
    if not okSeat or seat == nil then return true end
    local okDoor, door = pcall(vehicle.getPassengerDoor, vehicle, seat)
    if not okDoor or door == nil then return true end
    if door.getChildWindow == nil then return true end
    local okPart, part = pcall(door.getChildWindow, door)
    if not okPart or part == nil then return true end

    local okType, itemType = pcall(part.getItemType, part)
    local okItem, installed = pcall(part.getInventoryItem, part)
    if okType and itemType ~= nil and not (okItem and installed ~= nil) then
        return true
    end
    local okWindow, window = pcall(part.getWindow, part)
    if not okWindow or window == nil then return true end
    local okOpenable, openable = pcall(window.isOpenable, window)
    if not okOpenable or not openable then return true end
    local okOpen, isOpen = pcall(window.isOpen, window)
    return okOpen and isOpen == true
end

function Transfer.dropToFloor(items, playerObj)
    if not items or not playerObj then return 0 end
    if not Transfer.canDropOutsideVehicle(playerObj) then return 0 end
    local playerNum = playerObj:getPlayerNum()
    local dropped = 0
    local refusedMoveables = nil
    for i = 1, #items do
        local item = items[i]

        if item ~= nil and not item:isFavorite() then
            if not instanceof(item, "Moveable")
                    or item:CanBeDroppedOnFloor() then
                ISInventoryPaneContextMenu.dropItem(item, playerNum)
                dropped = dropped + 1
            else

                refusedMoveables = refusedMoveables or {}
                refusedMoveables[#refusedMoveables + 1] = item
            end
        end
    end
    return dropped, refusedMoveables
end

function Transfer.openMoveableCursor(playerObj, moveable)
    if playerObj == nil or moveable == nil then return false end
    if ISMoveableCursor == nil then return false end
    local okCell, cell = pcall(getCell)
    if not okCell or cell == nil then return false end
    local ok, err = pcall(function()
        local mo = ISMoveableCursor:new(playerObj)
        cell:setDrag(mo, mo.player)
        mo:setMoveableMode("place")
        mo:tryInitialItem(moveable)
    end)
    if not ok then
        Log.warn("Transfer.openMoveableCursor failed: " .. tostring(err))
        return false
    end
    return true
end
